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
	seq: number?, -- the current round's sequence number, from RoundInfo
	round: number?,
	revealSeconds: number?, -- set when the current round is reveal-then-hide
	targetSeq: number?, -- which round the target below belongs to
	targetColorId: number?,
	targetName: string?,
	targetRevealUntil: number?, -- server time the target hides, in reveal-then-hide rounds
	playersLeft: number?,
	winnerNames: { string }?,
}

-- What the HUD shows for the target right now.
export type TargetView = {
	colorId: number?, -- nil when there is no target to show yet
	name: string?,
	hidden: boolean, -- true while the target is secret (before the reveal, or after it in Run)
}

export type Lines = {
	state: string,
	round: string,
	target: string,
	timer: string,
	playersLeft: string,
}

local EMPTY = "-"
-- Shown in place of the target name while it is hidden (D-06 replaces it with art).
local HIDDEN = "?"

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
		model.seq = nil
		model.round = nil
		model.revealSeconds = nil
		model.targetSeq = nil
		model.targetColorId = nil
		model.targetName = nil
		model.targetRevealUntil = nil
		model.playersLeft = nil
	end
end

function HudModel.applyRoundInfo(model: Model, payload: Types.RoundInfoPayload)
	model.seq = payload.seq
	model.round = payload.round
	model.revealSeconds = payload.revealSeconds
	model.playersLeft = payload.playersLeft
end

-- `now` is the server time the payload arrived. The server times the reveal from Run start,
-- but the target reaches each client a little later, so a client that gets it while the
-- reveal is still running shows it for the full revealSeconds from arrival. A client that
-- gets it after the reveal ended (a late joiner) keeps it hidden.
function HudModel.applyTarget(model: Model, payload: Types.TargetAnnouncedPayload, now: number)
	model.targetSeq = payload.seq
	model.targetColorId = payload.colorId
	model.targetName = payload.name
	local revealUntil = payload.revealUntil
	local revealSeconds = payload.revealSeconds
	if revealUntil and revealSeconds and now < revealUntil then
		revealUntil = math.max(revealUntil, now + revealSeconds)
	end
	model.targetRevealUntil = revealUntil
end

-- The target to show at server time `now`. A target only counts for the round it was sent
-- for (matching seq), so an old target never shows in a new round, whichever of RoundInfo
-- and TargetAnnounced arrives first. In a reveal-then-hide round the target is hidden until
-- the server reveals it, and again from revealUntil until Run ends.
function HudModel.targetView(model: Model, now: number): TargetView
	local current = model.seq ~= nil and model.targetSeq == model.seq
	if current then
		local revealUntil = model.targetRevealUntil
		local hiddenNow = revealUntil ~= nil and model.state == "Run" and now >= revealUntil
		if hiddenNow then
			return { colorId = nil, name = nil, hidden = true }
		end
		return { colorId = model.targetColorId, name = model.targetName, hidden = false }
	end
	-- No target for this round yet: secret in a reveal round, otherwise not sent yet.
	return { colorId = nil, name = nil, hidden = model.revealSeconds ~= nil }
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
	local target = HudModel.targetView(model, now)
	local targetText = if target.hidden then HIDDEN else (target.name or EMPTY)
	return {
		state = stateText,
		round = "Round: " .. (if round then tostring(round) else EMPTY),
		target = "Target: " .. targetText,
		timer = "Time: " .. (if endsAt then HudModel.formatSeconds(endsAt - now) else EMPTY),
		playersLeft = "Players left: " .. (if playersLeft then tostring(playersLeft) else EMPTY),
	}
end

return HudModel
