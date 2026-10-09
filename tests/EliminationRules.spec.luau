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
