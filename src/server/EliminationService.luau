--!strict
-- Decides which survivors are safe once the non-target tiles have been removed.
-- With Config.Elimination.logDecisions on, logs one line per survivor explaining why.

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
			name = tile.Name,
			colorId = ArenaService.getTileColorId(tile),
		})
	end
	return footprints
end

-- A decision that needs no measuring: the player has no live character, or already died.
local function outWithoutPosition(reason: string): EliminationRules.Decision
	return { safe = false, reason = reason, tile = nil, outsideEdge = 0, belowTop = 0 }
end

-- Judges one player and returns the decision plus the position measured, if any.
local function judge(
	player: Player,
	died: boolean,
	footprints: { EliminationRules.Footprint }
): (EliminationRules.Decision, Vector3?)
	if died then
		return outWithoutPosition("died this round"), nil
	end
	local character = player.Character
	if not character then
		return outWithoutPosition("no character"), nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return outWithoutPosition("no root part"), nil
	end
	local position = root.Position
	if not humanoid or humanoid.Health <= 0 then
		return outWithoutPosition("dead"), position
	end
	local decision =
		EliminationRules.decide(position.X, position.Y, position.Z, footprints, Config.Elimination)
	return decision, position
end

-- Returns the players who are safe. Players in `died` died during the round (including a
-- character reset), which counts as elimination even if they have respawned.
function EliminationService.findSafe(players: { Player }, died: { [Player]: boolean }): { Player }
	local footprints = getFootprints()
	local safe: { Player } = {}
	for _, player in players do
		local decision, position = judge(player, died[player] == true, footprints)
		if decision.safe then
			table.insert(safe, player)
		end
		if Config.Elimination.logDecisions then
			local measured = if position
				then { x = position.X, y = position.Y, z = position.Z }
				else nil
			print(
				"[Elimination] "
					.. EliminationRules.formatDecision(
						player.Name,
						decision,
						measured,
						Config.Elimination
					)
			)
		end
	end
	return safe
end

return EliminationService
