-- Checks 3D model files (models/*.rbxm, models/*.rbxmx) against the "Builder rules" in the
-- 3D models workbook. Used by tests/Models.spec.luau, run with Lune.
--
-- Rules:
--   1. Every part is anchored.
--   2. Plain parts use only the six palette colours or neutrals (no green). Parts that
--      carry a texture (SurfaceAppearance, Decal, Texture) are checked when the texture
--      is prepared, not here.
--   3. Nothing visible inside the tile square near tile height, and nothing collidable
--      in or next to it (a rim players could stand on), down to the fall-out clearance.
--   4. Lobby and SpectatorArea have a Spawns folder with enough flat, anchored parts.
--   5. Phone budgets: a part count, and triangle counts from models/manifest.json
--      (Roblox cannot report mesh triangles from a model file, so the asset prep step
--      records them).

local roblox = require("@lune/roblox")

local ModelRules = {}

export type Arena = {
	centerX: number,
	centerZ: number,
	halfSize: number, -- half the tile square, in studs
	tileTopY: number,
	fallMargin: number, -- Config.Elimination.fallMargin
}

export type Limits = {
	headroom: number, -- studs above the tile tops that must stay clear
	fallClearance: number, -- studs below the tile tops where nothing may collide
	rimGap: number, -- studs around the square where nothing may collide (no standable rim)
	minSpawns: number,
	maxParts: number,
	maxTrianglesPerMesh: number,
	maxTrianglesPerModel: number,
	colorTolerance: number, -- per channel, 0 to 1
	maxNeutralSaturation: number, -- HSV saturation at or below this counts as neutral
}

export type Manifest = { [string]: { meshes: { [string]: number } } }

local SPAWN_AREAS = { Lobby = true, SpectatorArea = true }
local TEXTURE_CLASSES = { "SurfaceAppearance", "Decal", "Texture" }

local function hexToRgb(hex: string): { number }
	return {
		tonumber(string.sub(hex, 2, 3), 16) / 255,
		tonumber(string.sub(hex, 4, 5), 16) / 255,
		tonumber(string.sub(hex, 6, 7), 16) / 255,
	}
end

-- Reads a property, or nil if Lune does not know it or the file did not set it.
local function read(instance: any, property: string): any
	local ok, value = pcall(function()
		return instance[property]
	end)
	return if ok then value else nil
end

local function boundsOf(part: any): (any, any)
	local cframe = part.CFrame
	local half = part.Size / 2
	local lo = { math.huge, math.huge, math.huge }
	local hi = { -math.huge, -math.huge, -math.huge }
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local corner = cframe * roblox.Vector3.new(half.X * sx, half.Y * sy, half.Z * sz)
				local values = { corner.X, corner.Y, corner.Z }
				for axis = 1, 3 do
					lo[axis] = math.min(lo[axis], values[axis])
					hi[axis] = math.max(hi[axis], values[axis])
				end
			end
		end
	end
	return lo, hi
end

local function overlapsBox(
	lo: { number },
	hi: { number },
	boxLo: { number },
	boxHi: { number }
): boolean
	for axis = 1, 3 do
		if hi[axis] <= boxLo[axis] or lo[axis] >= boxHi[axis] then
			return false
		end
	end
	return true
end

local function isTextured(part: any): boolean
	for _, className in TEXTURE_CLASSES do
		if part:FindFirstChildWhichIsA(className) then
			return true
		end
	end
	return false
end

local function isAllowedColor(color: any, palette: { { number } }, limits: Limits): boolean
	local r, g, b = color.R, color.G, color.B
	local maxValue = math.max(r, g, b)
	local minValue = math.min(r, g, b)
	local saturation = if maxValue == 0 then 0 else (maxValue - minValue) / maxValue
	if saturation <= limits.maxNeutralSaturation then
		return true
	end
	for _, rgb in palette do
		local close = math.abs(r - rgb[1]) <= limits.colorTolerance
			and math.abs(g - rgb[2]) <= limits.colorTolerance
			and math.abs(b - rgb[3]) <= limits.colorTolerance
		if close then
			return true
		end
	end
	return false
end

-- Returns a list of human-readable violations for one model. An empty list means it passes.
function ModelRules.check(
	model: any,
	paletteHexes: { string },
	arena: Arena,
	limits: Limits,
	manifest: Manifest?
): { string }
	local violations: { string } = {}
	local function fail(message: string)
		table.insert(violations, model.Name .. ": " .. message)
	end

	local palette = {}
	for _, hex in paletteHexes do
		table.insert(palette, hexToRgb(hex))
	end

	local visibleLo = {
		arena.centerX - arena.halfSize,
		arena.tileTopY - arena.fallMargin,
		arena.centerZ - arena.halfSize,
	}
	local visibleHi = {
		arena.centerX + arena.halfSize,
		arena.tileTopY + limits.headroom,
		arena.centerZ + arena.halfSize,
	}
	local solidHalf = arena.halfSize + limits.rimGap
	local solidLo = {
		arena.centerX - solidHalf,
		arena.tileTopY - limits.fallClearance,
		arena.centerZ - solidHalf,
	}
	local solidHi =
		{ arena.centerX + solidHalf, arena.tileTopY + limits.headroom, arena.centerZ + solidHalf }

	local parts = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end

	if #parts > limits.maxParts then
		fail(string.format("%d parts, over the budget of %d", #parts, limits.maxParts))
	end

	local modelTriangles = 0
	local meshes = if manifest and manifest[model.Name] then manifest[model.Name].meshes else {}

	for _, part in parts do
		local name = part:GetFullName()
		if read(part, "Anchored") ~= true then
			fail(name .. " is not anchored")
		end

		local transparency = read(part, "Transparency") or 0
		local collides = read(part, "CanCollide") ~= false
		local lo, hi = boundsOf(part)
		if transparency < 1 and overlapsBox(lo, hi, visibleLo, visibleHi) then
			fail(name .. " is visible inside the tile square near tile height")
		end
		if collides and overlapsBox(lo, hi, solidLo, solidHi) then
			fail(name .. " can be collided with in or next to the tile square")
		end

		if transparency < 1 and not isTextured(part) then
			local color = read(part, "Color")
			if color and not isAllowedColor(color, palette, limits) then
				fail(
					string.format(
						"%s colour (%d, %d, %d) is not a palette colour or a neutral",
						name,
						math.round(color.R * 255),
						math.round(color.G * 255),
						math.round(color.B * 255)
					)
				)
			end
		end

		if part:IsA("MeshPart") then
			local triangles = meshes[part.Name]
			if triangles == nil then
				fail(name .. " is a MeshPart with no triangle count in models/manifest.json")
			else
				modelTriangles += triangles
				if triangles > limits.maxTrianglesPerMesh then
					fail(
						string.format(
							"%s has %d triangles, over the %d per mesh limit",
							name,
							triangles,
							limits.maxTrianglesPerMesh
						)
					)
				end
			end
		end
	end

	if modelTriangles > limits.maxTrianglesPerModel then
		fail(
			string.format(
				"%d triangles in total, over the budget of %d",
				modelTriangles,
				limits.maxTrianglesPerModel
			)
		)
	end

	if SPAWN_AREAS[model.Name] then
		local spawns = model:FindFirstChild("Spawns")
		local count = 0
		if spawns then
			for _, child in spawns:GetChildren() do
				if child:IsA("BasePart") then
					count += 1
					if child.CFrame.UpVector.Y < 0.99 then
						fail(child:GetFullName() .. " is not flat side up")
					end
				end
			end
		end
		if count < limits.minSpawns then
			fail(string.format("Spawns has %d parts, needs at least %d", count, limits.minSpawns))
		end
	end

	return violations
end

return ModelRules
