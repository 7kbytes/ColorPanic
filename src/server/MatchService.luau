--!strict
-- Owns the match state machine and its timers. Only this service changes the match state.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local Util = require(ReplicatedStorage.Shared.Util)
local ArenaService = require(script.Parent.ArenaService)
local Broadcast = require(script.Parent.Broadcast)
local EliminationRules = require(script.Parent.EliminationRules)
local EliminationService = require(script.Parent.EliminationService)
local MatchFlow = require(script.Parent.MatchFlow)
local PlacementService = require(script.Parent.PlacementService)
local QueueRules = require(script.Parent.QueueRules)
local ResetAudit = require(script.Parent.ResetAudit)
local RoundDirector = require(script.Parent.RoundDirector)

type MatchState = Types.MatchState
type ColorId = Types.ColorId
type PlayerRole = Types.PlayerRole

local MatchService = {}

local state: MatchState = "Lobby"
local endsAt: number? = nil
local stateDuration: number? = nil -- full length of the current state, sent with endsAt
local round = 0
local inMatch = false
-- Pressed Play and not Leave. Only queued players count toward a match and get a character.
local queued: { [Player]: boolean } = {}
local lastRequestAt: { [Player]: number } = {} -- for the Play and Leave cooldown
local spawning: { [Player]: boolean } = {} -- a LoadCharacterAsync call is in flight
local survivors: { [Player]: boolean } = {}
local spectators: { [Player]: boolean } = {} -- pressed Play mid-match, wait for the next match
local started = false
local roundParams: Types.RoundParams? = nil -- set on entering RoundIntro
local diedThisRound: { [Player]: boolean } = {} -- survivors whose character died this round
local isReplay = false -- the current round is a replay after everyone fell
local replayPending = false -- the next RoundIntro replays the current round
local sharedWin = false -- everyone remaining failed a replay and shares the win
local matchResult: Types.MatchResultPayload? = nil -- set on entering Victory, cleared on Reset
-- Goes up by one on every RoundIntro, replays included; sent with RoundInfo and the target.
local roundSeq = 0
-- Reveal-then-hide (D-05): whether clients may be told this round's target yet, and the
-- server time the reveal ends (nil when the target stays visible).
local targetPublic = false
local revealUntil: number? = nil
local baselinePartCount = 0 -- workspace parts before the first match, for the reset audit
local rng = Random.new()
-- How long to wait for a new character's Humanoid before giving up on tracking its death.
local HUMANOID_TIMEOUT = 5
-- Player attribute mirroring MatchService.getRole: "Menu", "Lobby", "Survivor" or "Spectator".
local MATCH_ROLE_ATTRIBUTE = "MatchRole"

local function countPlayers(): number
	return #Players:GetPlayers()
end

-- Players who pressed Play. These, not everyone connected, count toward the minimum.
local function countQueued(): number
	local count = 0
	for _ in queued do
		count += 1
	end
	return count
end

local function countSurvivors(): number
	local count = 0
	for _ in survivors do
		count += 1
	end
	return count
end

local function getMinPlayers(): number
	return Util.getMinPlayers(Config.Match, RunService:IsStudio())
end

local function getDuration(nextState: MatchState): number?
	if nextState == "Lobby" then
		return nil
	elseif nextState == "Intermission" then
		return Config.Match.intermissionSeconds
	elseif nextState == "Run" then
		return if roundParams then roundParams.timerSeconds else nil
	elseif nextState == "RoundIntro" then
		return Config.StateSeconds.RoundIntro
	elseif nextState == "Elimination" then
		return Config.StateSeconds.Elimination
	elseif nextState == "RoundEnd" then
		return Config.StateSeconds.RoundEnd
	elseif nextState == "Victory" then
		return Config.StateSeconds.Victory
	end
	return Config.StateSeconds.Reset
end

-- Waits for `seconds`, checking `cancelIf` every poll. Returns false if cancelled.
local function waitFor(seconds: number, cancelIf: (() -> boolean)?): boolean
	local deadline = os.clock() + seconds
	while os.clock() < deadline do
		if cancelIf and cancelIf() then
			return false
		end
		task.wait(Config.Match.pollSeconds)
	end
	return true
end

local function resetRoundFlags()
	table.clear(diedThisRound)
	isReplay = false
	replayPending = false
	sharedWin = false
end

local function startMatch()
	inMatch = true
	round = 0
	table.clear(survivors)
	table.clear(spectators)
	resetRoundFlags()
	for player in queued do
		survivors[player] = true
	end
end

local function endMatch()
	inMatch = false
	round = 0
	table.clear(survivors)
	table.clear(spectators)
	resetRoundFlags()
end

local function getSurvivorList(): { Player }
	local list: { Player } = {}
	for player in survivors do
		table.insert(list, player)
	end
	return list
end

-- Where a player belongs right now: in the menu, on the arena, in the spectator area, or in
-- the lobby. A survivor who died this round waits in the spectator area until it resolves.
local function roleOf(player: Player): PlayerRole
	if not queued[player] then
		return "Menu"
	elseif survivors[player] and not diedThisRound[player] then
		return "Survivor"
	elseif survivors[player] or spectators[player] then
		return "Spectator"
	end
	return "Lobby"
end

-- Mirrors a player's role into a read-only attribute, so tools and later UI can read it.
-- The server alone decides roles; nothing reads this attribute back into game logic.
local function syncRole(player: Player)
	local role: PlayerRole = roleOf(player)
	if player:GetAttribute(MATCH_ROLE_ATTRIBUTE) ~= role then
		player:SetAttribute(MATCH_ROLE_ATTRIBUTE, role)
	end
end

local function syncAllRoles()
	for _, player in Players:GetPlayers() do
		syncRole(player)
	end
end

local function eliminate(player: Player)
	survivors[player] = nil
	spectators[player] = true
	syncRole(player)
	local playersLeft = countSurvivors()
	print(string.format("[Elimination] %s is out, %d left", player.Name, playersLeft))
	PlacementService.toSpectator(player)
	Remotes.PlayerEliminated.fireAll({ userId = player.UserId, playersLeft = playersLeft })
end

-- Runs at the end of the Elimination state, once players have had time to fall.
local function resolveRoundEnd()
	local list = getSurvivorList()
	local safe = EliminationService.findSafe(list, diedThisRound)
	local outcome = EliminationRules.resolveRound(#safe, #list, isReplay)

	if outcome == "replay" then
		replayPending = true
		print(string.format("[Elimination] All %d would be out, replaying round %d", #list, round))
		return
	elseif outcome == "sharedWin" then
		sharedWin = true
		print(
			string.format(
				"[Elimination] All %d fell again on the replay, they share the win",
				#list
			)
		)
		return
	end

	local isSafe: { [Player]: boolean } = {}
	for _, player in safe do
		isSafe[player] = true
	end
	for _, player in list do
		if not isSafe[player] then
			eliminate(player)
		end
	end
end

-- Side effects of entering a state, run before the state is announced.
local function onEnter(previous: MatchState, nextState: MatchState)
	if nextState == "RoundIntro" then
		if previous == "Intermission" then
			startMatch()
		end
		local replaying = replayPending
		replayPending = false
		isReplay = replaying
		if not replaying then
			round += 1
		end
		table.clear(diedThisRound)

		local params = RoundDirector.getRoundParams(Config, round, countSurvivors(), rng)
		if replaying then
			params.timerSeconds += Config.Elimination.replayTimerBonus
		end
		roundParams = params
		roundSeq += 1
		-- In a reveal-then-hide round the target stays secret until Run starts.
		targetPublic = params.revealSeconds == nil
		revealUntil = nil
		ArenaService.build(params.colorIds, {
			colorId = params.targetColorId,
			minCount = params.minTargetTiles,
		})
		-- Put players on the arena at match start, and again on a replay since everyone fell.
		if previous == "Intermission" or replaying then
			PlacementService.toArena(getSurvivorList())
		end
	elseif nextState == "RoundEnd" then
		resolveRoundEnd()
	elseif nextState == "Victory" then
		local winners = getSurvivorList()
		table.sort(winners, function(a, b)
			return a.DisplayName < b.DisplayName
		end)
		local result: Types.MatchResultPayload = { winnerUserIds = {}, winnerNames = {} }
		local names: { string } = {}
		for _, player in winners do
			table.insert(result.winnerUserIds, player.UserId)
			table.insert(result.winnerNames, player.DisplayName)
			table.insert(names, player.Name)
		end
		matchResult = result
		print(string.format("[Match] Winners: %s", table.concat(names, ", ")))
	elseif nextState == "Elimination" then
		if roundParams then
			ArenaService.removeNonTarget(roundParams.targetColorId)
		end
	elseif nextState == "Reset" then
		endMatch()
		roundParams = nil
		matchResult = nil
		-- Move everyone off the arena before its tiles are removed. Menu players have no
		-- character, and queued players stay queued for the next match.
		for player in queued do
			PlacementService.toLobby(player)
		end
		ArenaService.cleanup()
	end
end

local function getColorName(colorId: ColorId): string
	local colorDef = Util.getColorDef(Config.Colors, colorId)
	return if colorDef then colorDef.name else "Unknown"
end

-- Sends the current round number, timer and survivor count to one player, or to everyone
-- when `player` is nil. Does nothing outside a round.
local function sendRoundInfo(player: Player?)
	if not (inMatch and roundParams) then
		return
	end
	local payload = {
		seq = roundSeq,
		round = round,
		timerSeconds = roundParams.timerSeconds,
		playersLeft = countSurvivors(),
		revealSeconds = roundParams.revealSeconds,
	}
	if player then
		Remotes.RoundInfo.fireTo(player, payload)
	else
		Remotes.RoundInfo.fireAll(payload)
	end
end

-- Sends the current target color to one player, or to everyone when `player` is nil.
-- In a reveal-then-hide round nothing is sent before Run starts.
local function sendTarget(player: Player?)
	if not (inMatch and roundParams and targetPublic) then
		return
	end
	local payload = {
		seq = roundSeq,
		colorId = roundParams.targetColorId,
		name = getColorName(roundParams.targetColorId),
		revealUntil = revealUntil,
		revealSeconds = roundParams.revealSeconds,
	}
	if player then
		Remotes.TargetAnnounced.fireTo(player, payload)
	else
		Remotes.TargetAnnounced.fireAll(payload)
	end
end

-- Sends the winners to one player, or to everyone when `player` is nil. Only during Victory.
local function sendMatchResult(player: Player?)
	if not (state == "Victory" and matchResult) then
		return
	end
	if player then
		Remotes.MatchResult.fireTo(player, matchResult)
	else
		Remotes.MatchResult.fireAll(matchResult)
	end
end

-- Sends the current state to one player, or to everyone when `player` is nil.
local function sendState(player: Player?)
	local payload = { state = state, endsAt = endsAt, duration = stateDuration }
	if player then
		Remotes.StateChanged.fireTo(player, payload)
	else
		Remotes.StateChanged.fireAll(payload)
	end
end

-- Reveal-then-hide: once Run starts, shows everyone the target for revealSeconds, using the
-- same server clock as endsAt so every client hides it at the same moment.
local function sendReveal()
	if not (roundParams and roundParams.revealSeconds and not targetPublic) then
		return
	end
	targetPublic = true
	revealUntil = workspace:GetServerTimeNow() + roundParams.revealSeconds
	sendTarget(nil)
	print(
		string.format(
			"[Round] %d target %s, revealed for %.1f s",
			round,
			getColorName(roundParams.targetColorId),
			roundParams.revealSeconds
		)
	)
end

-- Sends `messages` in order (see Broadcast) to one player, or to everyone when `player` is nil.
local function send(messages: { Broadcast.Message }, player: Player?)
	for _, message in messages do
		if message == "MatchResult" then
			sendMatchResult(player)
		elseif message == "RoundInfo" then
			sendRoundInfo(player)
		elseif message == "Target" then
			sendTarget(player)
		elseif message == "StateChanged" then
			sendState(player)
		elseif message == "Reveal" and player == nil then
			sendReveal()
		end
	end
end

-- BaseParts in the workspace, not counting player characters (they come and go with players).
local function countWorkspaceParts(): number
	local characters: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(characters, player.Character)
		end
	end
	local count = 0
	for _, instance in workspace:GetDescendants() do
		if instance:IsA("BasePart") then
			local inCharacter = false
			for _, character in characters do
				if instance:IsDescendantOf(character) then
					inCharacter = true
					break
				end
			end
			if not inCharacter then
				count += 1
			end
		end
	end
	return count
end

-- Logs whether the match just reset cleanly: no tiles, no tracked players, no extra parts,
-- and every spawned character back in the lobby.
local function auditReset()
	local survivorCount = countSurvivors()
	local spectatorCount = 0
	for _ in spectators do
		spectatorCount += 1
	end
	local outsideLobby: { string } = {}
	for _, player in Players:GetPlayers() do
		local distance = PlacementService.distanceToLobby(player)
		if distance and distance > Config.Placement.lobbyCheckRadius then
			table.insert(outsideLobby, player.Name)
		end
	end
	local partCount = countWorkspaceParts()
	local problems = ResetAudit.findProblems({
		tileCount = #ArenaService.getTiles(),
		survivorCount = survivorCount,
		spectatorCount = spectatorCount,
		partCount = partCount,
		baselinePartCount = baselinePartCount,
		outsideLobby = outsideLobby,
	})
	if #problems == 0 then
		print(string.format("[Reset] Clean: 0 tiles, %d parts, everyone in the lobby", partCount))
	else
		warn("[Reset] Problems after reset: " .. table.concat(problems, "; "))
	end
end

local function transition(nextState: MatchState)
	local previous: MatchState = state
	onEnter(previous, nextState)
	-- Match start, a replay clearing deaths, and Reset all change roles in bulk.
	syncAllRoles()

	local duration = getDuration(nextState)
	state = nextState
	stateDuration = duration
	endsAt = if duration then workspace:GetServerTimeNow() + duration else nil

	print(
		string.format(
			"[Match] %s -> %s (round %d, players %d, queued %d, survivors %d)",
			previous,
			nextState,
			round,
			countPlayers(),
			countQueued(),
			countSurvivors()
		)
	)

	send(Broadcast.onTransition(nextState))
	if nextState == "Lobby" and previous == "Reset" then
		auditReset()
	end
end

-- Blocks for as long as the current state lasts.
local function runCurrentState()
	if state == "Lobby" then
		while countQueued() < getMinPlayers() do
			task.wait(Config.Match.pollSeconds)
		end
	elseif state == "Intermission" then
		waitFor(Config.Match.intermissionSeconds, function()
			return countQueued() < getMinPlayers()
		end)
	else
		waitFor(getDuration(state) or 0)
	end
end

-- Gives a queued player a new character. Characters do not load on their own (see start), so
-- this is the only place one is created. PlacementService puts it where the role says.
local function spawnCharacter(player: Player)
	if spawning[player] then
		return
	end
	spawning[player] = true
	task.spawn(function()
		local ok, err = pcall(function()
			player:LoadCharacterAsync()
		end)
		spawning[player] = nil
		if not ok and player.Parent then
			warn(string.format("[Queue] Could not spawn %s: %s", player.Name, tostring(err)))
		end
	end)
end

-- Removes a player's character, when they go back to the menu.
local function removeCharacter(player: Player)
	local character = player.Character
	if character then
		player.Character = nil
		character:Destroy()
	end
end

-- A survivor whose character dies during a round (including a reset) is out at the next check.
-- A queued player who dies gets a new character after Config.Queue.respawnSeconds.
local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", HUMANOID_TIMEOUT)
	if not humanoid or not humanoid:IsA("Humanoid") then
		return
	end
	humanoid.Died:Connect(function()
		local inRound = state == "RoundIntro" or state == "Run" or state == "Elimination"
		if inMatch and inRound and survivors[player] and not diedThisRound[player] then
			diedThisRound[player] = true
			syncRole(player)
			print(string.format("[Elimination] %s died during round %d", player.Name, round))
		end
		task.delay(Config.Queue.respawnSeconds, function()
			-- Only if still queued and nothing replaced this character in the meantime.
			if player.Parent and queued[player] and player.Character == character then
				spawnCharacter(player)
			end
		end)
	end)
end

-- Accepts a request only if the player is off cooldown. Every request, accepted or not,
-- restarts the cooldown, so spamming the button does nothing.
local function takeRequest(player: Player, kind: string): boolean
	local now = os.clock()
	local allowed =
		QueueRules.isOffCooldown(lastRequestAt[player], now, Config.Queue.requestCooldown)
	lastRequestAt[player] = now
	if not allowed then
		print(string.format("[Queue] Ignored %s from %s: too soon", kind, player.Name))
	end
	return allowed
end

-- Play: queue the player and give them a character, in the lobby or (mid-match) the
-- spectator area. They join the next match from there.
local function onRequestPlay(player: Player)
	if not takeRequest(player, "Play") then
		return
	end
	local role: PlayerRole = roleOf(player)
	if not QueueRules.canPlay(role) then
		print(string.format("[Queue] Ignored Play from %s: role is %s", player.Name, role))
		return
	end
	queued[player] = true
	if QueueRules.roleAfterPlay(inMatch) == "Spectator" then
		spectators[player] = true
	end
	syncRole(player)
	print(
		string.format(
			"[Queue] %s pressed Play, now %s (queued %d)",
			player.Name,
			roleOf(player),
			countQueued()
		)
	)
	spawnCharacter(player)
end

-- Leave: back to the menu, before a match starts only. If that drops the queue below the
-- minimum during Intermission, the countdown cancels on its next check.
local function onRequestLeave(player: Player)
	if not takeRequest(player, "Leave") then
		return
	end
	local role: PlayerRole = roleOf(player)
	if not QueueRules.canLeave(role, state) then
		print(
			string.format("[Queue] Ignored Leave from %s: role %s in %s", player.Name, role, state)
		)
		return
	end
	queued[player] = nil
	spectators[player] = nil
	syncRole(player)
	removeCharacter(player)
	print(string.format("[Queue] %s left the queue (queued %d)", player.Name, countQueued()))
end

local function onPlayerAdded(player: Player)
	-- Everyone starts in the menu, with no character, until they press Play.
	syncRole(player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	local character = player.Character
	if character then
		task.spawn(onCharacterAdded, player, character)
	end
	-- Bring the new player's HUD up to date, including the round in progress.
	send(Broadcast.onJoin(), player)
end

local function onPlayerRemoving(player: Player)
	-- Leaving removes the player from the survivor count without ending the round.
	local wasSurvivor = survivors[player] == true
	queued[player] = nil
	lastRequestAt[player] = nil
	spawning[player] = nil
	survivors[player] = nil
	spectators[player] = nil
	diedThisRound[player] = nil
	if wasSurvivor then
		sendRoundInfo(nil)
	end
end

function MatchService.getState(): MatchState
	return state
end

-- Where a player belongs right now (see roleOf). Also mirrored in the MatchRole attribute.
function MatchService.getRole(player: Player): PlayerRole
	return roleOf(player)
end

function MatchService.start()
	assert(not started, "MatchService.start() called twice")
	started = true

	-- Players start in the menu with no character. The server creates characters itself:
	-- on Play, and after a queued player dies (see spawnCharacter).
	Players.CharacterAutoLoads = false
	Remotes.RequestPlay.connect(onRequestPlay)
	Remotes.RequestLeave.connect(onRequestLeave)

	PlacementService.init(MatchService.getRole)
	-- Lobby and spectator areas exist now, and no match has built anything yet.
	baselinePartCount = countWorkspaceParts()

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	print(
		string.format(
			"[Match] Starting in Lobby (preset %s, round cap %s)",
			Config.activePreset,
			if Config.Match.maxRounds == math.huge then "none" else tostring(Config.Match.maxRounds)
		)
	)
	task.spawn(function()
		while true do
			runCurrentState()
			transition(MatchFlow.nextState(state, {
				playerCount = countQueued(),
				survivorCount = countSurvivors(),
				minPlayers = getMinPlayers(),
				sharedWin = sharedWin,
				round = round,
				maxRounds = Config.Match.maxRounds,
			}))
		end
	end)
end

return MatchService
