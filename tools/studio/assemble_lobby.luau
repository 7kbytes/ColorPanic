-- Studio command bar script (task 3D-02): assembles workspace.Lobby from the imported lobby
-- meshes (the 3D Importer puts each one in workspace as a Model of the same name).
-- Run in edit mode, then save workspace.Lobby to models/Lobby.rbxm (right click, Save to File).
-- Positions follow Config.Placement.lobbyOrigin: the centre of the walkable floor's top.

local ORIGIN = Vector3.new(0, 45, 100) -- keep in step with Config.Placement.lobbyOrigin

-- Heights measured on the prepared meshes (tools/blender), in studs above each mesh's bottom.
local BASE_TOP = 35.66 -- IslandBase: flat top
local TOP_FLOOR = 4.97 -- IslandTop: walkable floor
local PAD_TOP = 0.57 -- SpawnPad: top of the pad

local FLOOR_RADIUS = 33 -- inside IslandTop's rim
local RAIL_HEIGHT = 12
local RAIL_SEGMENTS = 24
local PAD_RING_RADIUS = 14
local PAD_COUNT = 12
local PLATFORM_RADIUS = 7
local PLATFORM_HEIGHT = 2.4

local function source(name: string): MeshPart
	local item = workspace:FindFirstChild(name)
	assert(item, "Missing imported mesh " .. name)
	local mesh = if item:IsA("MeshPart") then item else item:FindFirstChildWhichIsA("MeshPart", true)
	assert(mesh, name .. " has no MeshPart")
	return mesh
end

local lobby = Instance.new("Model")
lobby.Name = "Lobby"
local visuals = Instance.new("Folder")
visuals.Name = "Visuals"
visuals.Parent = lobby
local collision = Instance.new("Folder")
collision.Name = "Collision"
collision.Parent = lobby
local spawns = Instance.new("Folder")
spawns.Name = "Spawns"
spawns.Parent = lobby

-- Places a copy of a mesh with its bottom centre at `bottom`, turned `yaw` degrees.
local function place(name: string, bottom: Vector3, yaw: number): MeshPart
	local mesh = source(name):Clone()
	mesh.Name = name
	mesh.Anchored = true
	mesh.CanCollide = false
	mesh.CanTouch = false
	mesh.CanQuery = false
	mesh.CFrame = CFrame.new(bottom + Vector3.new(0, mesh.Size.Y / 2, 0))
		* CFrame.Angles(0, math.rad(yaw), 0)
	mesh.Parent = visuals
	return mesh
end

local function onRing(radius: number, degrees: number, y: number): Vector3
	local angle = math.rad(degrees)
	return Vector3.new(ORIGIN.X + math.cos(angle) * radius, y, ORIGIN.Z + math.sin(angle) * radius)
end

-- Faces the centre from a point on a ring.
local function facingCentre(degrees: number): number
	return -degrees - 90
end

local function invisible(name: string, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Transparency = 1
	part.CastShadow = false
	part.CanTouch = false
	part.Parent = parent
	return part
end

-- Island.
place("IslandBase", ORIGIN - Vector3.new(0, TOP_FLOOR + BASE_TOP, 0), 0)
place("IslandTop", ORIGIN - Vector3.new(0, TOP_FLOOR, 0), 0)
place("CentralPlatform", ORIGIN, 0)
place("EntranceArch", ORIGIN + Vector3.new(0, 0, -24), 0) -- the front faces the arena (-Z)

for index = 1, 4 do
	local degrees = 45 + (index - 1) * 90
	place("MarkerPillar", onRing(20, degrees, ORIGIN.Y), facingCentre(degrees))
end
for _, degrees in { 20, 90, 160 } do
	place("PalmTree", onRing(25, degrees, ORIGIN.Y), degrees)
end
for _, degrees in { 55, 125 } do
	place("RocksAndFlowers", onRing(26, degrees, ORIGIN.Y), degrees)
end
for _, degrees in { 235, 305 } do
	place("LampPost", onRing(26, degrees, ORIGIN.Y), facingCentre(degrees))
end

-- Spawn pads in a ring, each with a flat invisible spawn part flush with its top.
for index = 1, PAD_COUNT do
	local degrees = (index - 1) * 360 / PAD_COUNT
	place("SpawnPad", onRing(PAD_RING_RADIUS, degrees, ORIGIN.Y), 0)
	local spawn = invisible("Spawn" .. index, spawns)
	spawn.CanCollide = false
	spawn.CanQuery = false
	spawn.Size = Vector3.new(2, 0.2, 2)
	spawn.CFrame = CFrame.new(onRing(PAD_RING_RADIUS, degrees, ORIGIN.Y + PAD_TOP - 0.1))
end

-- A SpawnLocation on the floor in front of the platform, so the game does not add its
-- fallback in the middle of the platform.
local spawnLocation = Instance.new("SpawnLocation")
spawnLocation.Name = "LobbySpawnLocation"
spawnLocation.Anchored = true
spawnLocation.CanCollide = false
spawnLocation.CanQuery = false
spawnLocation.CanTouch = false
spawnLocation.Transparency = 1
spawnLocation.Neutral = true
spawnLocation.Duration = 0
spawnLocation.Size = Vector3.new(6, 1, 6)
spawnLocation.CFrame = CFrame.new(ORIGIN + Vector3.new(0, 0.5, -9))
spawnLocation.Parent = lobby

-- Collision: a floor disc, a ring of railing walls, and the central platform.
local floor = invisible("Floor", collision)
floor.Shape = Enum.PartType.Cylinder
floor.Size = Vector3.new(2, FLOOR_RADIUS * 2, FLOOR_RADIUS * 2)
floor.CFrame = CFrame.new(ORIGIN - Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.rad(90))

local railWidth = 2 * (FLOOR_RADIUS + 0.5) * math.tan(math.pi / RAIL_SEGMENTS) + 0.5
for index = 1, RAIL_SEGMENTS do
	local degrees = (index - 0.5) * 360 / RAIL_SEGMENTS
	local rail = invisible("Rail" .. index, collision)
	rail.Size = Vector3.new(1, RAIL_HEIGHT, railWidth)
	rail.CFrame = CFrame.new(onRing(FLOOR_RADIUS + 0.5, degrees, ORIGIN.Y + RAIL_HEIGHT / 2))
		* CFrame.Angles(0, -math.rad(degrees), 0)
end

local platform = invisible("Platform", collision)
platform.Shape = Enum.PartType.Cylinder
platform.Size = Vector3.new(PLATFORM_HEIGHT, PLATFORM_RADIUS * 2, PLATFORM_RADIUS * 2)
platform.CFrame = CFrame.new(ORIGIN + Vector3.new(0, PLATFORM_HEIGHT / 2, 0))
	* CFrame.Angles(0, 0, math.rad(90))

lobby.PrimaryPart = floor
lobby.Parent = workspace
print("ASSEMBLED Lobby", #visuals:GetChildren(), "meshes", #spawns:GetChildren(), "spawns")
