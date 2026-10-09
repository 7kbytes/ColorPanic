--# selene: allow(global_usage)
-- QA only. Server command bar: logs into _G.placelog each time a player's location changes
-- (Lobby, Arena, SpectatorArea, falling, not spawned), with server time, so it can be lined
-- up against the [Match] transitions. Read it back with: return table.concat(_G.placelog, "\n")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local half = Config.Arena.gridSize * Config.Arena.tileSize / 2
local arenaY = Config.Arena.origin[2]
local radius = Config.Placement.lobbyCheckRadius

local function nearArea(position: Vector3, areaName: string): boolean
	local area = workspace:FindFirstChild(areaName)
	local spawns = area and area:FindFirstChild("Spawns")
	if not spawns then
		return false
	end
	for _, spawnPart in spawns:GetChildren() do
		if spawnPart:IsA("BasePart") then
			local offset = position - spawnPart.Position
			if
				Vector3.new(offset.X, 0, offset.Z).Magnitude <= radius
				and math.abs(offset.Y) < 15
			then
				return true
			end
		end
	end
	return false
end

local function placeOf(player: Player): string
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return "not spawned"
	end
	local position = root.Position
	if
		math.abs(position.X) <= half + 2
		and math.abs(position.Z) <= half + 2
		and math.abs(position.Y - arenaY) < 10
	then
		return "Arena"
	elseif nearArea(position, "Lobby") then
		return "Lobby"
	elseif nearArea(position, "SpectatorArea") then
		return "SpectatorArea"
	elseif position.Y < arenaY - 10 then
		return "falling"
	end
	return "other"
end

_G.placelog = {}
_G.placeRecorderRunning = true
task.spawn(function()
	local last: { [Player]: string } = {}
	while _G.placeRecorderRunning do
		for _, player in Players:GetPlayers() do
			local place = placeOf(player)
			if last[player] ~= place then
				last[player] = place
				table.insert(
					_G.placelog,
					string.format(
						"%.2f %s -> %s",
						workspace:GetServerTimeNow() % 1000,
						player.Name,
						place
					)
				)
			end
		end
		task.wait(0.1)
	end
end)
return "recording placement"
