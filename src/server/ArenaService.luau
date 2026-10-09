--!strict
-- Builds the tile grid, assigns colors and removes tiles. Tiles live in workspace.Arena.Tiles.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Types = require(ReplicatedStorage.Shared.Types)
local ArenaLayout = require(script.Parent.ArenaLayout)

type ColorId = Types.ColorId

local ARENA_FOLDER_NAME = "Arena"
local TILES_FOLDER_NAME = "Tiles"
local COLOR_ATTRIBUTE = "ColorId"

local ArenaService = {}

local rng = Random.new()

local colorsById: { [ColorId]: Types.ColorDef } = {}
for _, colorDef in Config.Colors do
	colorsById[colorDef.id] = colorDef
end

local function getFolder(parent: Instance, name: string): Instance
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function getTilesFolder(): Instance
	return getFolder(getFolder(workspace, ARENA_FOLDER_NAME), TILES_FOLDER_NAME)
end

-- Returns the color id stored on a tile, or nil if it has none.
function ArenaService.getTileColorId(tile: Instance): ColorId?
	local value = tile:GetAttribute(COLOR_ATTRIBUTE)
	return if type(value) == "number" then value else nil
end

function ArenaService.getTiles(): { BasePart }
	local tiles: { BasePart } = {}
	for _, child in getTilesFolder():GetChildren() do
		if child:IsA("BasePart") then
			table.insert(tiles, child)
		end
	end
	return tiles
end

-- Destroys every tile.
function ArenaService.cleanup()
	local folder = getTilesFolder()
	folder:ClearAllChildren()
	print(string.format("[Arena] Cleaned up, %d tiles left", #folder:GetChildren()))
end

-- Replaces the grid with a fresh shuffled one using the given colors.
function ArenaService.build(colorIds: { ColorId }, guarantee: ArenaLayout.Guarantee?)
	ArenaService.cleanup()

	local gridSize = Config.Arena.gridSize
	local tileSize = Config.Arena.tileSize
	local origin = Config.Arena.origin
	local layout = ArenaLayout.generate(gridSize * gridSize, colorIds, rng, guarantee)
	local folder = getTilesFolder()
	local centerOffset = (gridSize - 1) / 2

	for row = 1, gridSize do
		for col = 1, gridSize do
			local colorId = layout[(row - 1) * gridSize + col]
			local colorDef = colorsById[colorId]
			assert(colorDef, string.format("Unknown color id %d", colorId))

			local tile = Instance.new("Part")
			tile.Name = string.format("Tile_%d_%d", row, col)
			tile.Anchored = true
			tile.Material = Enum.Material.SmoothPlastic
			tile.Size = Vector3.new(tileSize, Config.Arena.tileHeight, tileSize)
			tile.Position = Vector3.new(
				origin[1] + (col - 1 - centerOffset) * tileSize,
				origin[2],
				origin[3] + (row - 1 - centerOffset) * tileSize
			)
			tile.Color = Color3.fromRGB(colorDef.rgb[1], colorDef.rgb[2], colorDef.rgb[3])
			tile:SetAttribute(COLOR_ATTRIBUTE, colorId)
			tile.Parent = folder
		end
	end

	print(string.format("[Arena] Built %d tiles with %d colors", #folder:GetChildren(), #colorIds))
end

-- Destroys every tile that is not the target color. Returns how many tiles remain.
function ArenaService.removeNonTarget(targetColorId: ColorId): number
	local remaining = 0
	for _, tile in ArenaService.getTiles() do
		if ArenaService.getTileColorId(tile) == targetColorId then
			remaining += 1
		else
			tile:Destroy()
		end
	end
	print(string.format("[Arena] Removed non-target tiles, %d left", remaining))
	return remaining
end

return ArenaService
