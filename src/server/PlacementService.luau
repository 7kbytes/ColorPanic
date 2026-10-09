--!strict
-- Moves player characters to the lobby, the arena or the spectator area.
--
-- Spawn points come from workspace.Lobby.Spawns and workspace.SpectatorArea.Spawns (the
-- builder's naming). If those areas are missing, simple placeholder platforms are created and
-- tagged with a Placeholder attribute, so the builder's real areas take over with no code change.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)
local ArenaService = require(script.Parent.ArenaService)
local PlacementLayout = require(script.Parent.PlacementLayout)

type PlayerRole = Types.PlayerRole

local LOBBY_NAME = "Lobby"
local SPECTATOR_NAME = "SpectatorArea"
local SPAWNS_NAME = "Spawns"
local PLACEHOLDER_ATTRIBUTE = "Placeholder"
-- How long to wait for a new character's root part before giving up on placing it.
local ROOT_PART_TIMEOUT = 5
-- Size of the invisible spawn markers in placeholder areas.
local SPAWN_MARKER_SIZE = Vector3.new(2, 1, 2)

local PlacementService = {}

local rng = Random.new()
local getRole: ((Player) -> PlayerRole)? = nil
local nextSpawnIndex: { [string]: number } = {}
local initialized = false

local function toVector3(position: { number }): Vector3
	return Vector3.new(position[1], position[2], position[3])
end

-- Creates a placeholder platform with a Spawns folder, unless the area already exists.
local function ensureArea(name: string, origin: { number }, rgb: { number })
	if workspace:FindFirstChild(name) then
		return
	end
	local placement = Config.Placement
	local columns = placement.placeholderColumns
	local rows = math.ceil(placement.placeholderSpawnCount / columns)
	local center = toVector3(origin)

	local area = Instance.new("Folder")
	area.Name = name
	area:SetAttribute(PLACEHOLDER_ATTRIBUTE, true)

	local platform = Instance.new("Part")
	platform.Name = "Platform"
	platform.Anchored = true
	platform.Material = Enum.Material.SmoothPlastic
	platform.Color = Color3.fromRGB(rgb[1], rgb[2], rgb[3])
	platform.Size = Vector3.new(
		columns * placement.spawnSpacing + placement.platformMargin * 2,
		placement.platformThickness,
		rows * placement.spawnSpacing + placement.platformMargin * 2
	)
	platform.Position = center - Vector3.new(0, placement.platformThickness / 2, 0)
	platform.Parent = area

	local spawns = Instance.new("Folder")
	spawns.Name = SPAWNS_NAME
	spawns.Parent = area
	for i, offset in
		PlacementLayout.gridOffsets(
			placement.placeholderSpawnCount,
			columns,
			placement.spawnSpacing
		)
	do
		local spawnPart = Instance.new("Part")
		spawnPart.Name = "Spawn" .. i
		spawnPart.Anchored = true
		spawnPart.CanCollide = false
		spawnPart.CanQuery = false
		spawnPart.Transparency = 1
		spawnPart.Size = SPAWN_MARKER_SIZE
		spawnPart.Position = center + Vector3.new(offset[1], 0, offset[2])
		spawnPart.Parent = spawns
	end

	area.Parent = workspace
	print(string.format("[Placement] Created placeholder %s", name))
end

-- Returns the area's spawn parts sorted by name (Spawn1, Spawn2, ...).
local function getSpawns(areaName: string): { BasePart }
	local area = workspace:FindFirstChild(areaName)
	local folder = area and area:FindFirstChild(SPAWNS_NAME)
	local spawns: { BasePart } = {}
	if folder then
		for _, child in folder:GetChildren() do
			if child:IsA("BasePart") then
				table.insert(spawns, child)
			end
		end
	end
	table.sort(spawns, function(a, b)
		local aIndex = tonumber(string.match(a.Name, "%d+")) or 0
		local bIndex = tonumber(string.match(b.Name, "%d+")) or 0
		return aIndex < bIndex
	end)
	return spawns
end

-- Moves the character so its root sits spawnHeight studs above `surface`.
local function moveCharacter(player: Player, surface: Vector3)
	local character = player.Character
	if not character then
		return -- placed by CharacterAdded once it spawns
	end
	local root = character:FindFirstChild("HumanoidRootPart")
		or character:WaitForChild("HumanoidRootPart", ROOT_PART_TIMEOUT)
	if not root or character.Parent == nil then
		return
	end
	character:PivotTo(CFrame.new(surface + Vector3.new(0, Config.Placement.spawnHeight, 0)))
end

-- Moves a player to the next spawn in the area, cycling through the spawns.
local function moveToArea(player: Player, areaName: string)
	local spawns = getSpawns(areaName)
	if #spawns == 0 then
		warn(string.format("[Placement] %s has no spawns", areaName))
		return
	end
	local index = (nextSpawnIndex[areaName] or 0) % #spawns + 1
	nextSpawnIndex[areaName] = index
	local spawnPart = spawns[index]
	task.spawn(moveCharacter, player, spawnPart.Position + Vector3.new(0, spawnPart.Size.Y / 2, 0))
end

local function tileTop(tile: BasePart): Vector3
	return tile.Position + Vector3.new(0, tile.Size.Y / 2, 0)
end

function PlacementService.toLobby(player: Player)
	moveToArea(player, LOBBY_NAME)
end

-- Horizontal distance in studs from the player's character to the nearest lobby spawn,
-- or nil if the character has not spawned yet.
function PlacementService.distanceToLobby(player: Player): number?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return nil
	end
	local nearest: number? = nil
	for _, spawnPart in getSpawns(LOBBY_NAME) do
		local offset = root.Position - spawnPart.Position
		local distance = Vector3.new(offset.X, 0, offset.Z).Magnitude
		if nearest == nil or distance < nearest then
			nearest = distance
		end
	end
	return nearest
end

function PlacementService.toSpectator(player: Player)
	moveToArea(player, SPECTATOR_NAME)
end

-- Puts each player on a random tile of the current grid, one player per tile where possible.
function PlacementService.toArena(players: { Player })
	local tiles = ArenaService.getTiles()
	if #tiles == 0 then
		warn("[Placement] No arena tiles to place players on")
		return
	end
	local indices = PlacementLayout.pickTileIndices(#tiles, #players, rng)
	for i, player in players do
		task.spawn(moveCharacter, player, tileTop(tiles[indices[i]]))
	end
end

-- Places a player wherever their current role says they belong.
function PlacementService.placeByRole(player: Player)
	assert(getRole, "PlacementService.init() must run first")
	local role = getRole(player)
	if role == "Survivor" then
		PlacementService.toArena({ player })
	elseif role == "Spectator" then
		PlacementService.toSpectator(player)
	else
		PlacementService.toLobby(player)
	end
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function()
		PlacementService.placeByRole(player)
	end)
	if player.Character then
		PlacementService.placeByRole(player)
	end
end

-- Creates any missing placeholder areas and places every character as it spawns.
-- `roleOf` comes from MatchService, so the two modules do not require each other.
function PlacementService.init(roleOf: (Player) -> PlayerRole)
	assert(not initialized, "PlacementService.init() called twice")
	initialized = true
	getRole = roleOf

	ensureArea(LOBBY_NAME, Config.Placement.lobbyOrigin, Config.Placement.lobbyRgb)
	ensureArea(SPECTATOR_NAME, Config.Placement.spectatorOrigin, Config.Placement.spectatorRgb)

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return PlacementService
