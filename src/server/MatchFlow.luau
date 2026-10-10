--!strict
-- Pure match transition rules. No side effects and no world state, so it can be unit tested.

local Types = require(game:GetService("ReplicatedStorage").Shared.Types)

type MatchState = Types.MatchState

export type FlowContext = {
	playerCount: number, -- players queued to play (pressed Play), not everyone connected
	survivorCount: number, -- participants still in the match
	minPlayers: number, -- minimum players needed to start
	sharedWin: boolean?, -- everyone remaining failed a replayed round and shares the win
	round: number?, -- the round that just ended
	maxRounds: number?, -- last round of a match; after it, everyone still standing shares the win
}

local MatchFlow = {}

-- Returns the state that follows `state` once its wait has finished (or was cancelled).
function MatchFlow.nextState(state: MatchState, ctx: FlowContext): MatchState
	if state == "Lobby" then
		return if ctx.playerCount >= ctx.minPlayers then "Intermission" else "Lobby"
	elseif state == "Intermission" then
		return if ctx.playerCount >= ctx.minPlayers then "RoundIntro" else "Lobby"
	elseif state == "Victory" then
		return "Reset"
	elseif state == "Reset" then
		return "Lobby"
	end

	-- In-match states. If every participant has left, skip straight to Reset.
	if ctx.survivorCount == 0 then
		return "Reset"
	elseif state == "RoundIntro" then
		return "Run"
	elseif state == "Run" then
		return "Elimination"
	elseif state == "Elimination" then
		return "RoundEnd"
	end

	-- RoundEnd
	if ctx.sharedWin then
		return "Victory"
	end
	-- Round cap: after the last round everyone still standing shares the win. This also
	-- applies when everyone fell in the last round, which then ends instead of replaying.
	local round, maxRounds = ctx.round, ctx.maxRounds
	if round and maxRounds and round >= maxRounds then
		return "Victory"
	end
	return if ctx.survivorCount >= 2 then "RoundIntro" else "Victory"
end

return MatchFlow
