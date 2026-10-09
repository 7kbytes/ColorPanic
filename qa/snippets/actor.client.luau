--# selene: allow(global_usage)
-- QA only. Client command bar: during Run, this player walks as set by _G.qaMode.
--   "target": walk to the nearest tile of the target color (survives)
--   "wrong":  walk to the nearest tile of another color (falls when tiles drop)
--   "fall":   walk off the nearest edge of the arena (eliminated as fallen)
--   nil:      do nothing
-- Change the mode at any time with: _G.qaMode = "wrong"
--
-- The actor walks with Humanoid:MoveTo, like a real player. An earlier version teleported
-- the character with PivotTo on the client, and some of those teleports never reached the
-- server, so the server judged the player where they used to stand (issue #15).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer
local half = Config.Arena.gridSize * Config.Arena.tileSize / 2
local arenaY = Config.Arena.origin[2]
-- How far past the arena edge "fall" mode walks, in studs.
local FALL_OVERSHOOT = 10

local function targetColorId(hud: Instance): number?
	local name = string.match((hud :: any).Panel.target.Text, "Target: (%a+)")
	for _, color in Config.Colors do
		if color.name == name then
			return color.id
		end
	end
	return nil
end

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- The nearest tile that is (or, for "wrong", is not) the target color.
local function pickTile(tiles: Instance, position: Vector3, mode: string, target: number?)
	local best: BasePart? = nil
	local bestDistance = math.huge
	for _, tile in tiles:GetChildren() do
		if tile:IsA("BasePart") then
			local isTarget = tile:GetAttribute("ColorId") == target
			if (mode == "target") == isTarget then
				local distance = flatDistance(tile.Position, position)
				if distance < bestDistance then
					best, bestDistance = tile, distance
				end
			end
		end
	end
	return best
end

-- A point just past the arena edge nearest to `position`.
local function edgeExit(position: Vector3): Vector3
	local x, z = position.X, position.Z
	if math.abs(x) >= math.abs(z) then
		x = (if x >= 0 then 1 else -1) * (half + FALL_OVERSHOOT)
	else
		z = (if z >= 0 then 1 else -1) * (half + FALL_OVERSHOOT)
	end
	return Vector3.new(x, position.Y, z)
end

_G.qaActorRunning = true
task.spawn(function()
	local goalTile: BasePart? = nil
	while _G.qaActorRunning do
		local mode = _G.qaMode
		local hud = player.PlayerGui:FindFirstChild("HUD")
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local arena = workspace:FindFirstChild("Arena")
		local tiles = arena and arena:FindFirstChild("Tiles")
		local running = hud and (hud :: any).Panel.state.Text == "Run!"
		if mode and running and root and humanoid and tiles then
			local position = root.Position
			local onArena = math.abs(position.X) <= half + 2
				and math.abs(position.Z) <= half + 2
				and math.abs(position.Y - arenaY) < 10
			if onArena then
				if mode == "fall" then
					humanoid:MoveTo(edgeExit(position))
				else
					local target = targetColorId(hud :: Instance)
					local stillValid = goalTile
						and goalTile.Parent
						and (mode == "target") == (goalTile:GetAttribute("ColorId") == target)
					if not stillValid then
						goalTile = pickTile(tiles, position, mode, target)
					end
					if goalTile then
						humanoid:MoveTo(
							Vector3.new(goalTile.Position.X, position.Y, goalTile.Position.Z)
						)
					end
				end
			end
		else
			goalTile = nil
		end
		task.wait(0.3)
	end
end)
return string.format("walking actor for %s, mode %s", player.Name, tostring(_G.qaMode))
