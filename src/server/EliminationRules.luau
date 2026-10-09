--!strict
-- Pure elimination rules. No side effects and no world state, so they can be unit tested.

local EliminationRules = {}

-- The top face of a remaining tile, in studs.
export type Footprint = {
	x: number,
	z: number,
	halfX: number,
	halfZ: number,
	topY: number,
}

export type Rules = {
	fallMargin: number, -- studs below a tile top before a player counts as fallen
	edgeTolerance: number, -- studs past a tile edge that still count as standing on it
}

export type Outcome = "normal" | "replay" | "sharedWin"

-- A position is safe if it is over a remaining tile and has not fallen below it.
function EliminationRules.isSafe(
	x: number,
	y: number,
	z: number,
	footprints: { Footprint },
	rules: Rules
): boolean
	for _, tile in footprints do
		local overTile = math.abs(x - tile.x) <= tile.halfX + rules.edgeTolerance
			and math.abs(z - tile.z) <= tile.halfZ + rules.edgeTolerance
		if overTile and y >= tile.topY - rules.fallMargin then
			return true
		end
	end
	return false
end

-- Decides what happens at the end of a round (SPEC section 3 edge cases):
--   "normal"    eliminate everyone who is not safe
--   "replay"    nobody is safe: eliminate nobody and replay the round once
--   "sharedWin" nobody is safe on a replayed round: everyone remaining shares the win
function EliminationRules.resolveRound(
	safeCount: number,
	survivorCount: number,
	isReplay: boolean
): Outcome
	if survivorCount == 0 or safeCount > 0 then
		return "normal"
	end
	return if isReplay then "sharedWin" else "replay"
end

return EliminationRules
