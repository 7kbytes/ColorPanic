local Harness = require("./harness")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local Config = Harness.requireModule("ReplicatedStorage.Shared.Config")
local EliminationRules = Harness.requireModule("ServerScriptService.Server.EliminationRules")

local RULES = { fallMargin = 5, edgeTolerance = 1 }

-- One 10 x 10 tile centred on (0, 0) with its top at height 40.5.
local TILE = { x = 0, z = 0, halfX = 5, halfZ = 5, topY = 40.5 }

describe("EliminationRules.isSafe", function()
	it("is safe standing in the middle of a tile", function()
		expect(EliminationRules.isSafe(0, 43.5, 0, { TILE }, RULES)).toBe(true)
	end)

	it("is safe just past the edge, within the tolerance", function()
		expect(EliminationRules.isSafe(5.9, 43.5, 0, { TILE }, RULES)).toBe(true)
	end)

	it("is not safe beyond the tolerance", function()
		expect(EliminationRules.isSafe(6.1, 43.5, 0, { TILE }, RULES)).toBe(false)
	end)

	it("is safe slightly below the top, within the fall margin", function()
		expect(EliminationRules.isSafe(0, 36, 0, { TILE }, RULES)).toBe(true)
	end)

	it("is not safe after falling past the fall margin, even under a tile", function()
		expect(EliminationRules.isSafe(0, 35, 0, { TILE }, RULES)).toBe(false)
		expect(EliminationRules.isSafe(0, 3, 0, { TILE }, RULES)).toBe(false)
	end)

	it("is not safe when no tiles remain", function()
		expect(EliminationRules.isSafe(0, 43.5, 0, {}, RULES)).toBe(false)
	end)

	it("is safe on any one of several tiles", function()
		local other = { x = 20, z = -10, halfX = 5, halfZ = 5, topY = 40.5 }
		expect(EliminationRules.isSafe(21, 43, -12, { TILE, other }, RULES)).toBe(true)
		expect(EliminationRules.isSafe(10, 43, 0, { TILE, other }, RULES)).toBe(false)
	end)

	it("uses the Config values", function()
		expect(Config.Elimination.fallMargin).toBe(5)
		expect(Config.Elimination.edgeTolerance).toBe(1)
		expect(Config.Elimination.replayTimerBonus).toBe(3)
	end)
end)

describe("EliminationRules.resolveRound", function()
	local cases = {
		{ safe = 1, survivors = 2, replay = false, outcome = "normal" },
		{ safe = 2, survivors = 2, replay = false, outcome = "normal" },
		{ safe = 1, survivors = 5, replay = true, outcome = "normal" },
		{ safe = 0, survivors = 2, replay = false, outcome = "replay" },
		{ safe = 0, survivors = 1, replay = false, outcome = "replay" },
		{ safe = 0, survivors = 2, replay = true, outcome = "sharedWin" },
		{ safe = 0, survivors = 0, replay = false, outcome = "normal" },
	}
	for _, case in cases do
		local name = string.format(
			"%d safe of %d, replay=%s -> %s",
			case.safe,
			case.survivors,
			tostring(case.replay),
			case.outcome
		)
		it(name, function()
			expect(EliminationRules.resolveRound(case.safe, case.survivors, case.replay)).toBe(
				case.outcome
			)
		end)
	end
end)

describe("EliminationRules.decide", function()
	local NAMED =
		{ x = 0, z = 0, halfX = 5, halfZ = 5, topY = 40.5, name = "Tile_3_3", colorId = 4 }

	it("reports the tile it is safe on, with nothing past the edge or below the top", function()
		local decision = EliminationRules.decide(1, 43.5, -2, { NAMED }, RULES)
		expect(decision.safe).toBe(true)
		expect(decision.reason).toBe("safe")
		expect(decision.tile).toBe(NAMED)
		expect(decision.outsideEdge).toBe(0)
		expect(decision.belowTop).toBe(0)
	end)

	it("measures how far past the edge a safe player stands, within the tolerance", function()
		local decision = EliminationRules.decide(5.5, 43.5, 0, { NAMED }, RULES)
		expect(decision.safe).toBe(true)
		expect(decision.outsideEdge).toBeCloseTo(0.5)
	end)

	it("says not on a tile, naming the closest tile and the distance past its edge", function()
		local far = { x = 30, z = 0, halfX = 5, halfZ = 5, topY = 40.5, name = "Far" }
		local decision = EliminationRules.decide(8, 43.5, 0, { far, NAMED }, RULES)
		expect(decision.safe).toBe(false)
		expect(decision.reason).toBe("not on a tile")
		expect(decision.tile).toBe(NAMED)
		expect(decision.outsideEdge).toBeCloseTo(3)
	end)

	it("says fell too far when over a tile but past the fall margin", function()
		local decision = EliminationRules.decide(0, 30, 0, { NAMED }, RULES)
		expect(decision.safe).toBe(false)
		expect(decision.reason).toBe("fell too far")
		expect(decision.belowTop).toBeCloseTo(10.5)
	end)

	it("says no tiles left when the arena is empty", function()
		local decision = EliminationRules.decide(0, 43.5, 0, {}, RULES)
		expect(decision.safe).toBe(false)
		expect(decision.reason).toBe("no tiles left")
		expect(decision.tile).toBe(nil)
	end)

	it("agrees with isSafe", function()
		for _, point in { { 0, 43.5, 0 }, { 6.1, 43.5, 0 }, { 0, 35, 0 }, { 5.9, 36, 5.9 } } do
			local x, y, z = point[1], point[2], point[3]
			expect(EliminationRules.decide(x, y, z, { TILE }, RULES).safe).toBe(
				EliminationRules.isSafe(x, y, z, { TILE }, RULES)
			)
		end
	end)
end)

describe("EliminationRules.formatDecision", function()
	local NAMED =
		{ x = 15, z = -25, halfX = 5, halfZ = 5, topY = 40.5, name = "Tile_1_5", colorId = 5 }

	it("formats a safe decision", function()
		local decision = EliminationRules.decide(15, 43.6, -25, { NAMED }, RULES)
		local line = EliminationRules.formatDecision(
			"Player1",
			decision,
			{ x = 15, y = 43.6, z = -25 },
			RULES
		)
		expect(line).toBe(
			"Player1 safe tile=Tile_1_5 color=5 pos=(15.0, 43.6, -25.0) outside edge 0.0/1.0 below top 0.0/5.0"
		)
	end)

	it("formats an out decision with its reason", function()
		local decision = EliminationRules.decide(15, 20, -25, { NAMED }, RULES)
		local line =
			EliminationRules.formatDecision("Player2", decision, { x = 15, y = 20, z = -25 }, RULES)
		expect(line).toBe(
			"Player2 out (fell too far) tile=Tile_1_5 color=5 pos=(15.0, 20.0, -25.0) outside edge 0.0/1.0 below top 20.5/5.0"
		)
	end)

	it("formats a decision with no tile and no position", function()
		local decision =
			{ safe = false, reason = "died this round", tile = nil, outsideEdge = 0, belowTop = 0 }
		expect(EliminationRules.formatDecision("Player3", decision, nil, RULES)).toBe(
			"Player3 out (died this round)"
		)
	end)
end)
