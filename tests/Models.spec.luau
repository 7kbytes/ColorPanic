-- Checks every 3D model in models/ against the builder rules (tests/ModelRules.luau), and
-- checks the checker itself with small fixture models.

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local Harness = require("./harness")
local ModelRules = require("./ModelRules")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local Config = Harness.requireModule("ReplicatedStorage.Shared.Config")

local MODELS_DIR = "models"
-- Kept outside models/: Rojo would map a .json file there into Workspace as a ModuleScript.
local MANIFEST_PATH = "art/models_manifest.json"
local PROJECT_PATH = "default.project.json"

local Instance = roblox.Instance
local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame

local ARENA: ModelRules.Arena = {
	centerX = Config.Arena.origin[1],
	centerZ = Config.Arena.origin[3],
	halfSize = Config.Arena.gridSize * Config.Arena.tileSize / 2,
	tileTopY = Config.Arena.origin[2] + Config.Arena.tileHeight / 2,
	fallMargin = Config.Elimination.fallMargin,
}

-- Values from the 3D models workbook ("Builder rules") and Roblox's mesh limit.
local LIMITS: ModelRules.Limits = {
	headroom = 30, -- keeps the view of the tiles clear
	fallClearance = 10, -- the workbook: fall-out zone at least 10 studs under the tiles
	-- A running jump covers about 10 studs, so a solid rim closer than this to the edge
	-- tiles would be a safe spot.
	rimGap = 12,
	minSpawns = 12,
	maxParts = 400,
	maxTrianglesPerMesh = 20000, -- Roblox's documented per-mesh limit
	maxTrianglesPerModel = 80000, -- phone budget per model
	colorTolerance = 0.02,
	maxNeutralSaturation = 0.15,
}

local PALETTE = {}
for _, colorDef in Config.Colors do
	table.insert(PALETTE, colorDef.hex)
end

local function readManifest(): ModelRules.Manifest
	if not fs.isFile(MANIFEST_PATH) then
		return {}
	end
	return serde.decode("json", fs.readFile(MANIFEST_PATH))
end

local function listModelFiles(): { string }
	local files = {}
	for _, name in fs.readDir(MODELS_DIR) do
		if string.match(name, "%.rbxmx?$") then
			table.insert(files, name)
		end
	end
	table.sort(files)
	return files
end

-- Rojo names the mapped instance after the file, so the checker uses the file name too.
local function loadModel(fileName: string): any
	local roots = roblox.deserializeModel(fs.readFile(MODELS_DIR .. "/" .. fileName))
	local name = string.gsub(fileName, "%.rbxmx?$", "")
	if #roots == 1 then
		roots[1].Name = name
		return roots[1]
	end
	-- Several roots: Rojo maps them under one instance named after the file.
	local model = Instance.new("Folder")
	model.Name = name
	for _, root in roots do
		root.Parent = model
	end
	return model
end

-- Fixtures ----------------------------------------------------------------------------

local function part(parent: any, name: string, position: { number }, size: { number }): any
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = true
	p.Size = Vector3.new(size[1], size[2], size[3])
	p.CFrame = CFrame.new(position[1], position[2], position[3])
	p.Color = roblox.Color3.fromRGB(128, 128, 128)
	p.Parent = parent
	return p
end

local function cleanLobby(): any
	local model = Instance.new("Model")
	model.Name = "Lobby"
	part(model, "Floor", { 0, 0, 100 }, { 60, 1, 60 })
	local spawns = Instance.new("Folder")
	spawns.Name = "Spawns"
	spawns.Parent = model
	for i = 1, 12 do
		part(spawns, "Spawn" .. i, { (i - 6) * 6, 1, 100 }, { 2, 1, 2 })
	end
	return model
end

local function check(model: any, manifest: ModelRules.Manifest?): { string }
	return ModelRules.check(model, PALETTE, ARENA, LIMITS, manifest)
end

local function hasViolation(violations: { string }, needle: string): boolean
	for _, violation in violations do
		if string.find(violation, needle, 1, true) then
			return true
		end
	end
	return false
end

describe("ModelRules on fixtures", function()
	it("passes a clean lobby", function()
		expect(#check(cleanLobby())).toBe(0)
	end)

	it("flags an unanchored part", function()
		local model = cleanLobby()
		model.Floor.Anchored = false
		expect(hasViolation(check(model), "is not anchored")).toBe(true)
	end)

	it("flags a colour that is neither in the palette nor neutral (green)", function()
		local model = cleanLobby()
		model.Floor.Color = roblox.Color3.fromRGB(60, 190, 80)
		expect(hasViolation(check(model), "is not a palette colour")).toBe(true)
	end)

	it("accepts a palette colour", function()
		local model = cleanLobby()
		model.Floor.Color = roblox.Color3.fromHex(Config.Colors[1].hex)
		expect(#check(model)).toBe(0)
	end)

	it("skips the colour check for textured parts", function()
		local model = cleanLobby()
		model.Floor.Color = roblox.Color3.fromRGB(60, 190, 80)
		Instance.new("SurfaceAppearance").Parent = model.Floor
		expect(#check(model)).toBe(0)
	end)

	it("flags a visible part inside the tile square at tile height", function()
		local model = cleanLobby()
		local deco = part(model, "Deco", { 0, ARENA.tileTopY + 2, 0 }, { 2, 2, 2 })
		deco.CanCollide = false
		expect(hasViolation(check(model), "is visible inside the tile square")).toBe(true)
	end)

	it("flags a solid rim just outside the square at tile height", function()
		local model = cleanLobby()
		local rimX = ARENA.centerX + ARENA.halfSize + 3
		part(model, "Rim", { rimX, ARENA.tileTopY - 1, 0 }, { 4, 1, 60 })
		expect(hasViolation(check(model), "can be collided with")).toBe(true)
	end)

	it("allows a non-colliding rim, and a solid base well below the tiles", function()
		local model = cleanLobby()
		local rim = part(model, "Rim", { ARENA.halfSize + 3, ARENA.tileTopY - 1, 0 }, { 4, 1, 60 })
		rim.CanCollide = false
		part(model, "Base", { 0, ARENA.tileTopY - LIMITS.fallClearance - 5, 0 }, { 70, 4, 70 })
		expect(#check(model)).toBe(0)
	end)

	it("flags a lobby with too few spawns", function()
		local model = cleanLobby()
		model.Spawns.Spawn12:Destroy()
		expect(hasViolation(check(model), "needs at least 12")).toBe(true)
	end)

	it("flags a tilted spawn", function()
		local model = cleanLobby()
		local spawn = model.Spawns.Spawn1
		spawn.CFrame = spawn.CFrame * CFrame.Angles(math.rad(45), 0, 0)
		expect(hasViolation(check(model), "is not flat side up")).toBe(true)
	end)

	it("flags too many parts", function()
		local model = cleanLobby()
		for i = 1, LIMITS.maxParts do
			part(model, "Extra" .. i, { 0, 0, 200 }, { 1, 1, 1 })
		end
		expect(hasViolation(check(model), "over the budget")).toBe(true)
	end)

	it("needs a manifest triangle count for every MeshPart, within the limits", function()
		local model = cleanLobby()
		local mesh = Instance.new("MeshPart")
		mesh.Name = "Island"
		mesh.Anchored = true
		mesh.CanCollide = false
		mesh.Parent = model
		expect(hasViolation(check(model), "no triangle count")).toBe(true)
		expect(#check(model, { Lobby = { meshes = { Island = 9000 } } })).toBe(0)
		local over = check(model, { Lobby = { meshes = { Island = 25000 } } })
		expect(hasViolation(over, "per mesh limit")).toBe(true)
	end)
end)

describe("models/ folder", function()
	it("is mapped into Workspace without deleting what is already there", function()
		local project = serde.decode("json", fs.readFile(PROJECT_PATH))
		local workspace = project.tree.Workspace
		expect(workspace ~= nil).toBe(true)
		expect(workspace["$path"]).toBe(MODELS_DIR)
		expect(workspace["$ignoreUnknownInstances"]).toBe(true)
	end)

	it("has a readable manifest", function()
		local manifest = readManifest()
		for modelName, entry in manifest do
			expect(type(modelName)).toBe("string")
			for meshName, triangles in entry.meshes do
				expect(type(meshName)).toBe("string")
				expect(type(triangles)).toBe("number")
			end
		end
	end)

	local manifest = readManifest()
	for _, fileName in listModelFiles() do
		it(fileName .. " follows the builder rules", function()
			local violations = check(loadModel(fileName), manifest)
			if #violations > 0 then
				error(table.concat(violations, "\n        "), 0)
			end
		end)
	end
end)
