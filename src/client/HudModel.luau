--!strict
-- What the HUD shows, kept pure so it can be tested outside Studio.
-- It only stores what the server sent; the client never decides any of it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)
local Util = require(ReplicatedStorage.Shared.Util)

type MatchState = Types.MatchState
type ShapeId = Types.ShapeId

export type Model = {
	state: MatchState?,
	endsAt: number?,
	duration: number?, -- full length of the current state, for the timer bar
	seq: number?, -- the current round's sequence number, from RoundInfo
	round: number?,
	timerSeconds: number?, -- this round's Run length, from RoundInfo
	colorCount: number?,
	isReplay: boolean?,
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

-- The target card. hidden: show the secret look (Config.Hud.hiddenText) instead of a color.
export type TargetCard = {
	hidden: boolean,
	colorId: number?,
	name: string,
	shape: ShapeId?,
	hex: string?,
}

export type TimerView = {
	text: string,
	fraction: number, -- 1 when the state starts, 0 when it ends
	warning: boolean, -- the last Config.Hud.warningSeconds of Run
}

-- Everything the HUD draws. A nil piece is hidden, so nothing shows a placeholder like
-- "Round: -" while the server's data is still on its way (#17).
export type View = {
	status: string,
	roundText: string?,
	playersLeft: string?,
	target: TargetCard?,
	timer: TimerView?,
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
	model.duration = payload.duration
	-- MatchResult is only sent for Victory, so any other state clears it. It may arrive
	-- just before or just after the Victory state; either way the names are kept.
	if payload.state ~= "Victory" then
		model.winnerNames = nil
	end
	if OUT_OF_MATCH[payload.state] then
		model.seq = nil
		model.round = nil
		model.timerSeconds = nil
		model.colorCount = nil
		model.isReplay = nil
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
	model.timerSeconds = payload.timerSeconds
	model.colorCount = payload.colorCount
	model.isReplay = payload.replay
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

-- "Round 3", or "Round 3/8" when the match has a round cap.
function HudModel.formatRound(round: number, maxRounds: number): string
	if maxRounds == math.huge then
		return "Round " .. tostring(round)
	end
	return string.format("Round %d/%d", round, maxRounds)
end

local function isTimerState(state: MatchState?): boolean
	for _, timerState in Config.Hud.timerStates do
		if timerState == state then
			return true
		end
	end
	return false
end

-- What the HUD shows for `model` at server time `now`.
function HudModel.view(model: Model, now: number): View
	local state: MatchState? = model.state
	local round = model.round
	local status = if state then STATE_TEXT[state] else EMPTY
	if state == "Victory" and model.winnerNames then
		status = HudModel.formatWinners(model.winnerNames)
	end

	local card: TargetCard? = nil
	if round then
		local target = HudModel.targetView(model, now)
		if target.hidden then
			card = { hidden = true, name = Config.Hud.hiddenText }
		elseif target.colorId then
			local colorDef = Util.getColorDef(Config.Colors, target.colorId)
			card = {
				hidden = false,
				colorId = target.colorId,
				name = target.name or (if colorDef then colorDef.name else EMPTY),
				shape = if colorDef then colorDef.shape else nil,
				hex = if colorDef then colorDef.hex else nil,
			}
		end
	end

	local timer: TimerView? = nil
	local endsAt = model.endsAt
	if endsAt and isTimerState(state) then
		local remaining = math.max(0, endsAt - now)
		local duration = model.duration
		timer = {
			text = HudModel.formatSeconds(remaining),
			fraction = if duration and duration > 0
				then math.clamp(remaining / duration, 0, 1)
				else 1,
			warning = state == "Run" and remaining <= Config.Hud.warningSeconds,
		}
	end

	return {
		status = status,
		roundText = if round then HudModel.formatRound(round, Config.Match.maxRounds) else nil,
		playersLeft = if model.playersLeft then tostring(model.playersLeft) else nil,
		target = card,
		timer = timer,
	}
end

return HudModel
