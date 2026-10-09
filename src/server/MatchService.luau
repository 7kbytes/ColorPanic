--!strict
-- Owns the match state machine and its timers. Only this service changes the match state.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local Util = require(ReplicatedStorage.Shared.Util)
local MatchFlow = require(script.Parent.MatchFlow)

type MatchState = Types.MatchState

local MatchService = {}

local state: MatchState = "Lobby"
local endsAt: number? = nil
local round = 0
local inMatch = false
local survivors: { [Player]: boolean } = {}
local spectators: { [Player]: boolean } = {} -- joined mid-match, wait for the next match
local started = false

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

-- Placeholder until RoundDirector (S1-06) supplies the per-round timer.
local function getRunSeconds(): number
	return Config.Difficulty[1].timerStart
end

local function getDuration(nextState: MatchState): number?
	if nextState == "Lobby" then
		return nil
	elseif nextState == "Intermission" then
		return Config.Match.intermissionSeconds
	elseif nextState == "Run" then
		return getRunSeconds()
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

local function startMatch()
	inMatch = true
	round = 0
	table.clear(survivors)
	table.clear(spectators)
	for _, player in Players:GetPlayers() do
		survivors[player] = true
	end
end

local function endMatch()
	inMatch = false
	round = 0
	table.clear(survivors)
	table.clear(spectators)
end

-- Side effects of entering a state, run before the state is announced.
-- EliminationService (S1-08) will decide who is out on entering Elimination. Until then nobody is.
local function onEnter(previous: MatchState, nextState: MatchState)
	if nextState == "RoundIntro" then
		if previous == "Intermission" then
			startMatch()
		end
		round += 1
	elseif nextState == "Reset" then
		endMatch()
	end
end

local function transition(nextState: MatchState)
	local previous = state
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
		Remotes.RoundInfo.fireAll({
			round = round,
			timerSeconds = getRunSeconds(),
			playersLeft = countSurvivors(),
		})
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

local function onPlayerAdded(player: Player)
	if inMatch then
		spectators[player] = true
	end
	Remotes.StateChanged.fireTo(player, { state = state, endsAt = endsAt })
end

local function onPlayerRemoving(player: Player)
	-- Leaving removes the player from the survivor count without ending the round.
	survivors[player] = nil
	spectators[player] = nil
end

function MatchService.getState(): MatchState
	return state
end

function MatchService.start()
	assert(not started, "MatchService.start() called twice")
	started = true

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
			}))
		end
	end)
end

return MatchService
