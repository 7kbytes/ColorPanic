--!strict
-- The only place remotes are declared. The server creates the RemoteEvents once with
-- initServer(); both sides then use the typed channels below.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Types = require(script.Parent.Types)

local FOLDER_NAME = "Remotes"

-- Every remote, by name. Add new remotes here and as a channel below.
local NAMES = {
	"StateChanged",
	"RoundInfo",
	"TargetAnnounced",
	"PlayerEliminated",
	"MatchResult",
	"LobbyInfo",
	"RequestPlay",
	"RequestLeave",
	"PlayerDataUpdated",
}

-- A server to client channel. fireAll and fireTo run on the server only,
-- connect runs on the client only.
export type ServerToClient<T> = {
	fireAll: (payload: T) -> (),
	fireTo: (player: Player, payload: T) -> (),
	connect: (callback: (payload: T) -> ()) -> RBXScriptConnection,
}

local function getEvent(name: string): RemoteEvent
	if RunService:IsServer() then
		local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
		assert(folder, "Remotes.initServer() must run before remotes are used")
		return folder:FindFirstChild(name) :: RemoteEvent
	end
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
	return folder:WaitForChild(name) :: RemoteEvent
end

local function serverToClient<T>(name: string): ServerToClient<T>
	return {
		fireAll = function(payload: T)
			assert(RunService:IsServer(), "fireAll is server only")
			getEvent(name):FireAllClients(payload)
		end,
		fireTo = function(player: Player, payload: T)
			assert(RunService:IsServer(), "fireTo is server only")
			getEvent(name):FireClient(player, payload)
		end,
		connect = function(callback: (payload: T) -> ()): RBXScriptConnection
			assert(RunService:IsClient(), "connect is client only")
			return getEvent(name).OnClientEvent:Connect(callback)
		end,
	}
end

-- A client to server request with no payload. fire runs on the client only, connect on the
-- server only. The server gets only the sending player: anything else a client puts in the
-- request is dropped, and the server validates every request before acting on it.
export type ClientRequest = {
	fire: () -> (),
	connect: (callback: (player: Player) -> ()) -> RBXScriptConnection,
}

local function clientRequest(name: string): ClientRequest
	return {
		fire = function()
			assert(RunService:IsClient(), "fire is client only")
			getEvent(name):FireServer()
		end,
		connect = function(callback: (player: Player) -> ()): RBXScriptConnection
			assert(RunService:IsServer(), "connect is server only")
			return getEvent(name).OnServerEvent:Connect(function(player: Player)
				callback(player)
			end)
		end,
	}
end

local Remotes = {}

-- Client requests (D-16 join queue).
Remotes.RequestPlay = clientRequest("RequestPlay")
Remotes.RequestLeave = clientRequest("RequestLeave")

Remotes.StateChanged = serverToClient("StateChanged") :: ServerToClient<Types.StateChangedPayload>
Remotes.RoundInfo = serverToClient("RoundInfo") :: ServerToClient<Types.RoundInfoPayload>
Remotes.TargetAnnounced =
	serverToClient("TargetAnnounced") :: ServerToClient<Types.TargetAnnouncedPayload>
Remotes.PlayerEliminated =
	serverToClient("PlayerEliminated") :: ServerToClient<Types.PlayerEliminatedPayload>
Remotes.MatchResult = serverToClient("MatchResult") :: ServerToClient<Types.MatchResultPayload>
Remotes.LobbyInfo = serverToClient("LobbyInfo") :: ServerToClient<Types.LobbyInfoPayload>
Remotes.PlayerDataUpdated =
	serverToClient("PlayerDataUpdated") :: ServerToClient<Types.PlayerDataPayload>

-- Creates the Remotes folder and every RemoteEvent. Call once at server startup,
-- before any service fires. Safe to call again.
function Remotes.initServer()
	assert(RunService:IsServer(), "initServer is server only")
	local folder: Instance? = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if not folder then
		local newFolder = Instance.new("Folder")
		newFolder.Name = FOLDER_NAME
		newFolder.Parent = ReplicatedStorage
		folder = newFolder
	end
	assert(folder, "Remotes folder missing after creation")
	for _, name in NAMES do
		if not folder:FindFirstChild(name) then
			local event = Instance.new("RemoteEvent")
			event.Name = name
			event.Parent = folder
		end
	end
end

return Remotes
