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
local EliminationRules = require(script.Parent.EliminationRules)
local EliminationService = require(script.Parent.EliminationService)
local MatchFlow = require(script.Parent.MatchFlow)
local PlacementService = require(script.Parent.PlacementService)
local RoundDirector = require(script.Parent.RoundDirector)

type MatchState = Types.MatchState
type ColorId = Types.ColorId
type PlayerRole = Types.PlayerRole

local MatchService = {}

local state: MatchState = "Lobby"
local endsAt: number? = nil
local round = 0
local inMatch = false
local survivors: { [Player]: boolean } = {}
local spectators: { [Player]: boolean } = {} -- joined mid-match, wait for the next match
local started = false
local roundParams: Types.RoundParams? = nil -- set on entering RoundIntro
local diedThisRound: { [Player]: boolean } = {} -- survivors whose character died this round
local isReplay = false -- the current round is a replay after everyone fell
local replayPending = false -- the next RoundIntro replays the current round
local sharedWin = false -- everyone remaining failed a replay and shares the win
local rng = Random.new()
-- How long to wait for a new character's Humanoid before giving up on tracking its death.
local HUMANOID_TIMEOUT = 5

local function countPlayers(): number
	return #Players:GetPlayers()
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
	for _, player in Players:GetPlayers() do
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

local function eliminate(player: Player)
	survivors[player] = nil
	spectators[player] = true
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
		local names: { string } = {}
		for player in survivors do
			table.insert(names, player.Name)
		end
		print(string.format("[Match] Winners: %s", table.concat(names, ", ")))
	elseif nextState == "Elimination" then
		if roundParams then
			ArenaService.removeNonTarget(roundParams.targetColorId)
		end
	elseif nextState == "Reset" then
		endMatch()
		roundParams = nil
		-- Move everyone off the arena before its tiles are removed.
		for _, player in Players:GetPlayers() do
			PlacementService.toLobby(player)
		end
		ArenaService.cleanup()
	end
end

local function getColorName(colorId: ColorId): string
	for _, colorDef in Config.Colors do
		if colorDef.id == colorId then
			return colorDef.name
		end
	end
	return "Unknown"
end

-- Sends the current round number, timer and survivor count to one player, or to everyone
-- when `player` is nil. Does nothing outside a round.
local function sendRoundInfo(player: Player?)
	if not (inMatch and roundParams) then
		return
	end
	local payload = {
		round = round,
		timerSeconds = roundParams.timerSeconds,
		playersLeft = countSurvivors(),
	}
	if player then
		Remotes.RoundInfo.fireTo(player, payload)
	else
		Remotes.RoundInfo.fireAll(payload)
	end
end

-- Sends the current target color to one player, or to everyone when `player` is nil.
local function sendTarget(player: Player?)
	if not (inMatch and roundParams) then
		return
	end
	local payload = {
		colorId = roundParams.targetColorId,
		name = getColorName(roundParams.targetColorId),
	}
	if player then
		Remotes.TargetAnnounced.fireTo(player, payload)
	else
		Remotes.TargetAnnounced.fireAll(payload)
	end
end

local function transition(nextState: MatchState)
	local previous: MatchState = state
	onEnter(previous, nextState)

	local duration = getDuration(nextState)
	state = nextState
	endsAt = if duration then workspace:GetServerTimeNow() + duration else nil

	print(
		string.format(
			"[Match] %s -> %s (round %d, players %d, survivors %d)",
			previous,
			nextState,
			round,
			countPlayers(),
			countSurvivors()
		)
	)

	Remotes.StateChanged.fireAll({ state = state, endsAt = endsAt })
	if nextState == "RoundIntro" then
		sendRoundInfo(nil)
		sendTarget(nil)
	end
end

-- Blocks for as long as the current state lasts.
local function runCurrentState()
	if state == "Lobby" then
		while countPlayers() < getMinPlayers() do
			task.wait(Config.Match.pollSeconds)
		end
	elseif state == "Intermission" then
		waitFor(Config.Match.intermissionSeconds, function()
			return countPlayers() < getMinPlayers()
		end)
	else
		waitFor(getDuration(state) or 0)
	end
end

-- A survivor whose character dies during a round (including a reset) is out at the next check.
local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", HUMANOID_TIMEOUT)
	if not humanoid or not humanoid:IsA("Humanoid") then
		return
	end
	humanoid.Died:Connect(function()
		local inRound = state == "RoundIntro" or state == "Run" or state == "Elimination"
		if inMatch and inRound and survivors[player] and not diedThisRound[player] then
			diedThisRound[player] = true
			print(string.format("[Elimination] %s died during round %d", player.Name, round))
		end
	end)
end

local function onPlayerAdded(player: Player)
	if inMatch then
		spectators[player] = true
	end
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	local character = player.Character
	if character then
		task.spawn(onCharacterAdded, player, character)
	end
	-- Bring the new player's HUD up to date, including the round in progress.
	Remotes.StateChanged.fireTo(player, { state = state, endsAt = endsAt })
	sendRoundInfo(player)
	sendTarget(player)
end

local function onPlayerRemoving(player: Player)
	-- Leaving removes the player from the survivor count without ending the round.
	local wasSurvivor = survivors[player] == true
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

-- Where a player belongs right now: on the arena, in the spectator area, or in the lobby.
-- A survivor who died this round waits in the spectator area until the round is resolved.
function MatchService.getRole(player: Player): PlayerRole
	if survivors[player] and not diedThisRound[player] then
		return "Survivor"
	elseif survivors[player] or spectators[player] then
		return "Spectator"
	end
	return "Lobby"
end

function MatchService.start()
	assert(not started, "MatchService.start() called twice")
	started = true

	PlacementService.init(MatchService.getRole)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	print("[Match] Starting in Lobby")
	task.spawn(function()
		while true do
			runCurrentState()
			transition(MatchFlow.nextState(state, {
				playerCount = countPlayers(),
				survivorCount = countSurvivors(),
				minPlayers = getMinPlayers(),
				sharedWin = sharedWin,
			}))
		end
	end)
end

return MatchService
