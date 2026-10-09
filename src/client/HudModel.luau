--!strict
-- What the placeholder HUD shows, kept pure so it can be tested outside Studio.
-- It only stores what the server sent; the client never decides any of it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)

type MatchState = Types.MatchState

export type Model = {
	state: MatchState?,
	endsAt: number?,
	round: number?,
	targetName: string?,
	playersLeft: number?,
	winnerNames: { string }?,
}

export type Lines = {
	state: string,
	round: string,
	target: string,
	timer: string,
	playersLeft: string,
}

local EMPTY = "-"

local STATE_TEXT: { [string]: string } = {
	Lobby = "Waiting for players",
	Intermission = "Starting soon",
	RoundIntro = "Get ready",
	Run = "Run!",
	Elimination = "Tiles dropping",
	RoundEnd = "Round over",
	Victory = "Victory",
	Reset = "Resetting",
}

-- States outside a match. Entering one clears the round, target and players left.
local OUT_OF_MATCH: { [MatchState]: boolean } = {
	Lobby = true,
	Intermission = true,
	Reset = true,
}

local HudModel = {}

function HudModel.new(): Model
	return {}
end

function HudModel.applyState(model: Model, payload: Types.StateChangedPayload)
	model.state = payload.state
	model.endsAt = payload.endsAt
	-- MatchResult is only sent for Victory, so any other state clears it. It may arrive
	-- just before or just after the Victory state; either way the names are kept.
	if payload.state ~= "Victory" then
		model.winnerNames = nil
	end
	if OUT_OF_MATCH[payload.state] then
		model.round = nil
		model.targetName = nil
		model.playersLeft = nil
	end
end

function HudModel.applyRoundInfo(model: Model, payload: Types.RoundInfoPayload)
	model.round = payload.round
	model.playersLeft = payload.playersLeft
end

function HudModel.applyTarget(model: Model, payload: Types.TargetAnnouncedPayload)
	model.targetName = payload.name
end

function HudModel.applyEliminated(model: Model, payload: Types.PlayerEliminatedPayload)
	model.playersLeft = payload.playersLeft
end

function HudModel.applyMatchResult(model: Model, payload: Types.MatchResultPayload)
	model.winnerNames = table.clone(payload.winnerNames)
end

-- "Winner: A", "Winners: A and B", "Winners: A, B and C", or with more than
-- Config.Hud.maxWinnerNames winners "Winners: A, B, C and 2 more". Plain "Victory" if empty.
function HudModel.formatWinners(names: { string }): string
	local count = #names
	if count == 0 then
		return STATE_TEXT.Victory
	elseif count == 1 then
		return "Winner: " .. names[1]
	end

	local shown = math.min(count, Config.Hud.maxWinnerNames)
	local listed = table.move(names, 1, shown, 1, {})
	local last: string
	if shown < count then
		last = string.format("%d more", count - shown)
	else
		last = table.remove(listed) :: string
	end
	return "Winners: " .. table.concat(listed, ", ") .. " and " .. last
end

-- Seconds left as text: tenths below Config.Hud.decimalBelowSeconds, whole seconds above.
-- Tenths round down and whole seconds round up, so the display never jumps backwards.
function HudModel.formatSeconds(remaining: number): string
	local seconds = math.max(0, remaining)
	if seconds < Config.Hud.decimalBelowSeconds then
		return string.format("%.1f", math.floor(seconds * 10) / 10)
	end
	return tostring(math.ceil(seconds))
end

-- The HUD text for `model` at server time `now`.
function HudModel.lines(model: Model, now: number): Lines
	local state = model.state
	local endsAt = model.endsAt
	local round = model.round
	local playersLeft = model.playersLeft
	local winnerNames = model.winnerNames
	local stateText = if state then STATE_TEXT[state] else EMPTY
	if state == "Victory" and winnerNames then
		stateText = HudModel.formatWinners(winnerNames)
	end
	return {
		state = stateText,
		round = "Round: " .. (if round then tostring(round) else EMPTY),
		target = "Target: " .. (model.targetName or EMPTY),
		timer = "Time: " .. (if endsAt then HudModel.formatSeconds(endsAt - now) else EMPTY),
		playersLeft = "Players left: " .. (if playersLeft then tostring(playersLeft) else EMPTY),
	}
end

return HudModel
