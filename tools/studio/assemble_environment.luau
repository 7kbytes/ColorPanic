-- Studio command bar script (tasks 3D-04 to 3D-06): builds workspace.SpectatorArea,
-- workspace.ArenaIsland and workspace.CloudSea from the imported lobby meshes, kept in
-- ServerStorage.ImportedLobbyMeshes in the scratch place (lobby_assembly.rbxl).
-- Run in edit mode, then save each model to models/<Name>.rbxm (right click, Save to File).

local SPECTATOR_ORIGIN = Vector3.new(0, 50, -70) -- keep in step with Config.Placement
local ARENA_CENTER = Vector3.new(0, 40, 0) -- Config.Arena.origin
local TILE_TOP = ARENA_CENTER.Y + 0.5

-- Heights measured on the prepared meshes (tools/blender), in studs above each mesh's bottom,
-- at their prepared size.
local BASE_TOP = 35.66
local TOP_FLOOR = 4.97
local PAD_TOP = 0.57

local sources = game.ServerStorage.ImportedLobbyMeshes

local function source(name)
	local item = sources:FindFirstChild(name)
	assert(item, "Missing imported mesh " .. name)
	local mesh = if item:IsA("MeshPart") then item else item:FindFirstChildWhichIsA("MeshPart", true)
	assert(mesh, name .. " has no MeshPart")
	return mesh
end

local function folder(name, parent)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- Places a copy of a mesh, scaled, with its bottom centre at `bottom`, turned `yaw` degrees.
local function place(name, parent, bottom, yaw, scale)
	local mesh = source(name):Clone()
	mesh.Name = name
	mesh.Size = mesh.Size * (scale or 1)
	mesh.Anchored = true
	mesh.CanCollide = false
	mesh.CanTouch = false
	mesh.CanQuery = false
	mesh.CFrame = CFrame.new(bottom + Vector3.new(0, mesh.Size.Y / 2, 0))
		* CFrame.Angles(0, math.rad(yaw), 0)
	mesh.Parent = parent
	return mesh
end

local function onRing(center, radius, degrees, y)
	local angle = math.rad(degrees)
	return Vector3.new(center.X + math.cos(angle) * radius, y, center.Z + math.sin(angle) * radius)
end

local function invisible(name, parent)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Transparency = 1
	part.CastShadow = false
	part.CanTouch = false
	part.Parent = parent
	return part
end

-- Spectator area: a smaller copy of the lobby island facing the arena, 12 pads, railings.
do
	local O = SPECTATOR_ORIGIN
	local scale = 0.55
	local model = Instance.new("Model")
	model.Name = "SpectatorArea"
	local visuals = folder("Visuals", model)
	local collision = folder("Collision", model)
	local spawns = folder("Spawns", model)

	place("IslandBase", visuals, O - Vector3.new(0, (TOP_FLOOR + BASE_TOP) * scale, 0), 180, scale)
	place("IslandTop", visuals, O - Vector3.new(0, TOP_FLOOR * scale, 0), 0, scale)
	for _, degrees in { 60, 120 } do
		place("LampPost", visuals, onRing(O, 15, degrees, O.Y), -degrees - 90)
	end
	for _, degrees in { 210, 330 } do
		place("MarkerPillar", visuals, onRing(O, 15, degrees, O.Y), -degrees - 90)
	end

	local padRadius = 10
	for index = 1, 12 do
		local degrees = (index - 1) * 30
		place("SpawnPad", visuals, onRing(O, padRadius, degrees, O.Y), 0)
		local spawn = invisible("Spawn" .. index, spawns)
		spawn.CanCollide = false
		spawn.CanQuery = false
		spawn.Size = Vector3.new(2, 0.2, 2)
		spawn.CFrame = CFrame.new(onRing(O, padRadius, degrees, O.Y + PAD_TOP - 0.1))
	end

	local floorRadius = 33 * scale
	local floor = invisible("Floor", collision)
	floor.Shape = Enum.PartType.Cylinder
	floor.Size = Vector3.new(2, floorRadius * 2, floorRadius * 2)
	floor.CFrame = CFrame.new(O - Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.rad(90))
	local segments = 20
	local railWidth = 2 * (floorRadius + 0.5) * math.tan(math.pi / segments) + 0.5
	for index = 1, segments do
		local degrees = (index - 0.5) * 360 / segments
		local rail = invisible("Rail" .. index, collision)
		rail.Size = Vector3.new(1, 12, railWidth)
		rail.CFrame = CFrame.new(onRing(O, floorRadius + 0.5, degrees, O.Y + 6))
			* CFrame.Angles(0, -math.rad(degrees), 0)
	end

	model.PrimaryPart = floor
	model.Parent = workspace
end

-- Arena island: the island mesh floating under the tile grid. It never collides, so falling
-- players drop past it, and its top stays more than 10 studs under the tiles.
do
	local scale = 0.75
	local model = Instance.new("Model")
	model.Name = "ArenaIsland"
	local top = TILE_TOP - 12
	place(
		"IslandBase",
		model,
		Vector3.new(ARENA_CENTER.X, top - BASE_TOP * scale, ARENA_CENTER.Z),
		90,
		scale
	)
	model.Parent = workspace
end

-- Cloud sea: a soft white floor over the baseplate (players who fall land in the clouds)
-- and cloud meshes drifting around the islands.
do
	local model = Instance.new("Model")
	model.Name = "CloudSea"
	local floor = Instance.new("Part")
	floor.Name = "CloudFloor"
	floor.Anchored = true
	floor.CanTouch = false
	floor.Material = Enum.Material.SmoothPlastic
	floor.Color = Color3.fromRGB(236, 244, 255)
	floor.Size = Vector3.new(2048, 2, 2048)
	floor.CFrame = CFrame.new(0, 1, 0)
	floor.Parent = model

	local clouds = folder("Clouds", model)
	local placements = {
		{ 140, 15, 8, 1.2 },
		{ 160, 75, 14, 1 },
		{ 180, 140, 10, 1.4 },
		{ 150, 200, 18, 1 },
		{ 170, 255, 6, 1.3 },
		{ 200, 310, 12, 1.1 },
		{ 90, 300, 4, 0.8 },
		{ 95, 230, 6, 0.9 },
		{ 230, 45, 20, 1.5 },
		{ 240, 175, 16, 1.5 },
	}
	for _, p in placements do
		local radius, degrees, y, scale = p[1], p[2], p[3], p[4]
		place("Cloud", clouds, onRing(Vector3.new(0, 0, 30), radius, degrees, y), degrees, scale)
	end
	model.PrimaryPart = floor
	model.Parent = workspace
end

print("ASSEMBLED environment")
