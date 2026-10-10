--!strict
-- What the lobby panel shows (D-13), kept pure so it can be tested outside Studio. The queue
-- numbers come from the server's LobbyInfo; the role from the MatchRole attribute.

export type View = {
	title: string,
	count: string?, -- "2 players ready", or nil when the count is not shown
	status: string,
}

local LobbyModel = {}

-- "1 player ready", "3 players ready".
function LobbyModel.formatReady(queued: number): string
	return string.format("%d %s ready", queued, if queued == 1 then "player" else "players")
end

-- The panel for `role` in match `state`, or nil when it is hidden (in the menu and in a match).
-- `info` is nil until the first LobbyInfo arrives.
function LobbyModel.view(
	role: string?,
	state: string?,
	info: { queued: number, needed: number }?
): View?
	if role == "Spectator" then
		return { title = "Next match", count = nil, status = "You'll play when this match ends" }
	end
	if role ~= "Lobby" or not (state == "Lobby" or state == "Intermission") then
		return nil
	end
	local count = if info then LobbyModel.formatReady(info.queued) else nil
	if state == "Intermission" then
		return { title = "Lobby", count = count, status = "Get ready!" }
	end
	if not info then
		return { title = "Lobby", count = nil, status = "Waiting for players" }
	end
	local missing = info.needed - info.queued
	local status = if missing > 0
		then string.format("Waiting for %d more", missing)
		else "Starting soon"
	return { title = "Lobby", count = count, status = status }
end

return LobbyModel
