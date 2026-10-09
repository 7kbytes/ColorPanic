local Harness = require("./harness")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local Config = Harness.requireModule("ReplicatedStorage.Shared.Config")
local ArenaLayout = Harness.requireModule("ServerScriptService.Server.ArenaLayout")
local RoundDirector = Harness.requireModule("ServerScriptService.Server.RoundDirector")

local TILE_COUNT = Config.Arena.gridSize * Config.Arena.gridSize

local function countColor(layout: { number }, colorId: number): number
	local count = 0
	for _, id in layout do
		if id == colorId then
			count += 1
		end
	end
	return count
end

describe("ArenaLayout.generate", function()
	it("spreads 3 colors evenly over 36 tiles", function()
		local layout = ArenaLayout.generate(TILE_COUNT, { 1, 2, 3 }, Harness.fakeRandom(7))
		expect(#layout).toBe(TILE_COUNT)
		for colorId = 1, 3 do
			expect(countColor(layout, colorId)).toBe(12)
		end
	end)

	it("raises the target color to the guaranteed minimum", function()
		local layout = ArenaLayout.generate(
			TILE_COUNT,
			{ 1, 2, 3, 4, 5, 6 },
			Harness.fakeRandom(3),
			{ colorId = 2, minCount = 10 }
		)
		expect(#layout).toBe(TILE_COUNT)
		expect(countColor(layout, 2)).toBe(10)
	end)

	it("clamps a guarantee larger than the grid to every tile", function()
		local layout = ArenaLayout.generate(
			4,
			{ 1, 2 },
			Harness.fakeRandom(1),
			{ colorId = 1, minCount = 99 }
		)
		expect(countColor(layout, 1)).toBe(4)
	end)

	it("shuffles: different seeds give different layouts", function()
		local a = ArenaLayout.generate(TILE_COUNT, { 1, 2, 3 }, Harness.fakeRandom(1))
		local b = ArenaLayout.generate(TILE_COUNT, { 1, 2, 3 }, Harness.fakeRandom(2))
		local same = true
		for i = 1, TILE_COUNT do
			if a[i] ~= b[i] then
				same = false
			end
		end
		expect(same).toBe(false)
	end)
end)

describe("Fairness rule end to end (RoundDirector + ArenaLayout)", function()
	it(
		"every grid has enough target tiles for 1 to 12 survivors, rounds 1 to 12, 200 seeds",
		function()
			for seed = 1, 200 do
				for survivors = 1, 12 do
					local round = ((seed + survivors) % 12) + 1
					local rng = Harness.fakeRandom(seed * 100 + survivors)
					local params = RoundDirector.getRoundParams(Config, round, survivors, rng)
					local layout = ArenaLayout.generate(TILE_COUNT, params.colorIds, rng, {
						colorId = params.targetColorId,
						minCount = params.minTargetTiles,
					})
					expect(#layout).toBe(TILE_COUNT)
					expect(countColor(layout, params.targetColorId)).toBeAtLeast(
						math.ceil(survivors / 2)
					)
					local allowed = {}
					for _, colorId in params.colorIds do
						allowed[colorId] = true
					end
					for _, colorId in layout do
						expect(allowed[colorId]).toBe(true)
					end
				end
			end
		end
	)
end)
