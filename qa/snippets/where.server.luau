-- QA only. Server command bar: where is each player's character right now?
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local half = Config.Arena.gridSize * Config.Arena.tileSize / 2
local arenaY = Config.Arena.origin[2]

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
				Vector3.new(offset.X, 0, offset.Z).Magnitude <= Config.Placement.lobbyCheckRadius
			then
				if math.abs(offset.Y) < 15 then
					return true
				end
			end
		end
	end
	return false
end

local lines = {}
for _, player in Players:GetPlayers() do
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local place
	if not root then
		place = "not spawned"
	else
		local position = root.Position
		-- The arena box goes first: the spectator radius reaches past the arena's edge.
		if
			math.abs(position.X) <= half + 2
			and math.abs(position.Z) <= half + 2
			and math.abs(position.Y - arenaY) < 10
		then
			place = "Arena"
		elseif nearArea(position, "Lobby") then
			place = "Lobby"
		elseif nearArea(position, "SpectatorArea") then
			place = "SpectatorArea"
		elseif position.Y < arenaY - 10 then
			place = "falling"
		else
			place = string.format("other (%.0f, %.0f, %.0f)", position.X, position.Y, position.Z)
		end
	end
	table.insert(lines, string.format("%s: %s", player.Name, place))
end
table.sort(lines)
return string.format("%.1f\n", workspace:GetServerTimeNow() % 1000) .. table.concat(lines, "\n")
