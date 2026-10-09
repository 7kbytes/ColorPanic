--# selene: allow(global_usage)
-- QA only. Client command bar: during Run, this player acts as set by _G.qaMode.
--   "target": stand on a tile of the target color (survives)
--   "wrong":  stand on a tile of another color (falls when tiles drop)
--   "fall":   drop below the arena (eliminated as fallen)
--   nil:      do nothing
-- Change the mode at any time with: _G.qaMode = "wrong"
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer
local half = Config.Arena.gridSize * Config.Arena.tileSize / 2
local arenaY = Config.Arena.origin[2]

local function targetColorId(hud: Instance): number?
	local name = string.match((hud :: any).Panel.target.Text, "Target: (%a+)")
	for _, color in Config.Colors do
		if color.name == name then
			return color.id
		end
	end
	return nil
end

local function standingOn(position: Vector3, tile: BasePart): boolean
	local offset = position - tile.Position
	return math.abs(offset.X) < tile.Size.X / 2 and math.abs(offset.Z) < tile.Size.Z / 2
end

_G.qaActorRunning = true
task.spawn(function()
	while _G.qaActorRunning do
		local mode = _G.qaMode
		local hud = player.PlayerGui:FindFirstChild("HUD")
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local arena = workspace:FindFirstChild("Arena")
		local tiles = arena and arena:FindFirstChild("Tiles")
		if mode and hud and root and tiles and (hud :: any).Panel.state.Text == "Run!" then
			local position = root.Position
			local onArena = math.abs(position.X) <= half + 2
				and math.abs(position.Z) <= half + 2
				and position.Y > arenaY - 5
				and position.Y < arenaY + 10
			if onArena then
				if mode == "fall" then
					character:PivotTo(CFrame.new(position.X, arenaY - 60, position.Z))
				else
					local target = targetColorId(hud)
					local wanted: { BasePart } = {}
					for _, tile in tiles:GetChildren() do
						if tile:IsA("BasePart") then
							local isTarget = tile:GetAttribute("ColorId") == target
							if (mode == "target") == isTarget then
								table.insert(wanted, tile)
							end
						end
					end
					local already = false
					for _, tile in wanted do
						if standingOn(position, tile) then
							already = true
						end
					end
					if not already and #wanted > 0 then
						local tile = wanted[(math.abs(player.UserId) % #wanted) + 1]
						character:PivotTo(CFrame.new(tile.Position + Vector3.new(0, 4, 0)))
					end
				end
			end
		end
		task.wait(0.3)
	end
end)
return string.format("actor running for %s, mode %s", player.Name, tostring(_G.qaMode))
