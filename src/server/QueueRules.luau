--!strict
-- Pure join queue rules (D-16). No side effects and no world state, so they can be tested.

local Types = require(game:GetService("ReplicatedStorage").Shared.Types)

type MatchState = Types.MatchState
type PlayerRole = Types.PlayerRole

local QueueRules = {}

-- Play is only accepted from the menu.
function QueueRules.canPlay(role: PlayerRole): boolean
	return role == "Menu"
end

-- Leave is only accepted from the lobby, before a match starts. Spectators and survivors
-- cannot leave mid-match.
function QueueRules.canLeave(role: PlayerRole, state: MatchState): boolean
	return role == "Lobby" and (state == "Lobby" or state == "Intermission")
end

-- Whether a new request is allowed, given when the player's last accepted or rejected
-- request arrived (nil if never). Times are in seconds.
function QueueRules.isOffCooldown(lastRequestAt: number?, now: number, cooldown: number): boolean
	return lastRequestAt == nil or now - lastRequestAt >= cooldown
end

-- Where a player goes when Play is accepted: the spectator area during a match (they join
-- the next one), the lobby otherwise.
function QueueRules.roleAfterPlay(inMatch: boolean): PlayerRole
	return if inMatch then "Spectator" else "Lobby"
end

return QueueRules
