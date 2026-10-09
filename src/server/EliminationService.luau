--!strict
-- Decides which survivors are safe once the non-target tiles have been removed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local ArenaService = require(script.Parent.ArenaService)
local EliminationRules = require(script.Parent.EliminationRules)

local EliminationService = {}

local function getFootprints(): { EliminationRules.Footprint }
	local footprints: { EliminationRules.Footprint } = {}
	for _, tile in ArenaService.getTiles() do
		table.insert(footprints, {
			x = tile.Position.X,
			z = tile.Position.Z,
			halfX = tile.Size.X / 2,
			halfZ = tile.Size.Z / 2,
			topY = tile.Position.Y + tile.Size.Y / 2,
		})
	end
	return footprints
end

-- Returns whether a player's character is alive and standing on a remaining tile.
local function isPlayerSafe(player: Player, footprints: { EliminationRules.Footprint }): boolean
	local character = player.Character
	if not character then
		return false
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return false
	end
	local position = root.Position
	return EliminationRules.isSafe(
		position.X,
		position.Y,
		position.Z,
		footprints,
		Config.Elimination
	)
end

-- Returns the players who are safe. Players in `died` died during the round (including a
-- character reset), which counts as elimination even if they have respawned.
function EliminationService.findSafe(players: { Player }, died: { [Player]: boolean }): { Player }
	local footprints = getFootprints()
	local safe: { Player } = {}
	for _, player in players do
		if not died[player] and isPlayerSafe(player, footprints) then
			table.insert(safe, player)
		end
	end
	return safe
end

return EliminationService
