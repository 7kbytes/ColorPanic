--!strict
-- The order MatchService sends its remotes in. Kept pure so the order can be tested.
-- The data a state needs goes out before the StateChanged that makes the HUD show it, so a
-- client never draws a state with its round details missing (#17). Separate remotes are not
-- promised to arrive in order, so HudModel also hides any HUD piece whose data is missing.

local Types = require(game:GetService("ReplicatedStorage").Shared.Types)

type MatchState = Types.MatchState

-- RoundInfo: round, timer and players left. Target: the target color, if it is public yet.
-- Reveal: the reveal-then-hide target, sent once Run has started.
export type Message = "MatchResult" | "RoundInfo" | "Target" | "StateChanged" | "Reveal"

local Broadcast = {}

-- Messages to everyone when the match enters `nextState`, in order.
function Broadcast.onTransition(nextState: MatchState): { Message }
	if nextState == "Victory" then
		return { "MatchResult", "StateChanged" }
	elseif nextState == "RoundIntro" then
		return { "RoundInfo", "Target", "StateChanged" }
	elseif nextState == "Run" then
		-- The reveal is timed from Run start, so it follows the state.
		return { "StateChanged", "Reveal" }
	end
	return { "StateChanged" }
end

-- Messages to a player who just joined, bringing their HUD up to date, in order.
function Broadcast.onJoin(): { Message }
	return { "MatchResult", "RoundInfo", "Target", "StateChanged" }
end

return Broadcast
