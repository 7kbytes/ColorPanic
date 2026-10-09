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
	name: string?, -- for the decision log only
	colorId: number?, -- for the decision log only
}

-- Why a survivor was judged safe or out, for the decision log.
export type Decision = {
	safe: boolean,
	reason: string, -- "safe", "not on a tile", "fell too far", "no tiles left"
	tile: Footprint?, -- the tile that made them safe, or the closest one
	outsideEdge: number, -- studs past that tile's edge, 0 when over it
	belowTop: number, -- studs below that tile's top, 0 when at or above it
}

export type Rules = {
	fallMargin: number, -- studs below a tile top before a player counts as fallen
	edgeTolerance: number, -- studs past a tile edge that still count as standing on it
}

export type Outcome = "normal" | "replay" | "sharedWin"

-- Decides whether a position is safe and explains why. Safe means within edgeTolerance of
-- a remaining tile's edge and no more than fallMargin below its top. If several tiles
-- qualify the first is reported; if none do, the closest tile (by edge, then height) is.
function EliminationRules.decide(
	x: number,
	y: number,
	z: number,
	footprints: { Footprint },
	rules: Rules
): Decision
	local best: Footprint? = nil
	local bestOutside = math.huge
	local bestBelow = math.huge
	for _, tile in footprints do
		local outside =
			math.max(math.abs(x - tile.x) - tile.halfX, math.abs(z - tile.z) - tile.halfZ, 0)
		local below = math.max(tile.topY - y, 0)
		if outside <= rules.edgeTolerance and below <= rules.fallMargin then
			return {
				safe = true,
				reason = "safe",
				tile = tile,
				outsideEdge = outside,
				belowTop = below,
			}
		end
		if outside < bestOutside or (outside == bestOutside and below < bestBelow) then
			best, bestOutside, bestBelow = tile, outside, below
		end
	end
	if not best then
		return {
			safe = false,
			reason = "no tiles left",
			tile = nil,
			outsideEdge = math.huge,
			belowTop = math.huge,
		}
	end
	local reason = if bestOutside > rules.edgeTolerance then "not on a tile" else "fell too far"
	return {
		safe = false,
		reason = reason,
		tile = best,
		outsideEdge = bestOutside,
		belowTop = bestBelow,
	}
end

-- A position is safe if it is over a remaining tile and has not fallen below it.
function EliminationRules.isSafe(
	x: number,
	y: number,
	z: number,
	footprints: { Footprint },
	rules: Rules
): boolean
	return EliminationRules.decide(x, y, z, footprints, rules).safe
end

-- One decision log line, for example:
-- Player1 safe tile=Tile_1_5 color=5 pos=(15.0, 43.6, -25.0) outside edge 0.0/1.0 below top 0.0/5.0
-- `position` is nil when the player had no character to measure.
function EliminationRules.formatDecision(
	playerName: string,
	decision: Decision,
	position: { x: number, y: number, z: number }?,
	rules: Rules
): string
	local verdict = if decision.safe then "safe" else string.format("out (%s)", decision.reason)
	local tile = decision.tile
	local tileText = if tile
		then string.format(
			" tile=%s color=%s",
			tile.name or "?",
			if tile.colorId then tostring(tile.colorId) else "?"
		)
		else ""
	local posText = if position
		then string.format(" pos=(%.1f, %.1f, %.1f)", position.x, position.y, position.z)
		else ""
	local measureText = if tile
		then string.format(
			" outside edge %.1f/%.1f below top %.1f/%.1f",
			decision.outsideEdge,
			rules.edgeTolerance,
			decision.belowTop,
			rules.fallMargin
		)
		else ""
	return playerName .. " " .. verdict .. tileText .. posText .. measureText
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
