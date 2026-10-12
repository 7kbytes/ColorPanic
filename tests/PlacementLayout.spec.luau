local Harness = require("./harness")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local PlacementLayout = Harness.requireModule("ServerScriptService.Server.PlacementLayout")
local Config = Harness.requireModule("ReplicatedStorage.Shared.Config")

describe("PlacementLayout.pickTileIndices", function()
	it("returns distinct in-range indices when there are enough tiles, 200 seeds", function()
		for seed = 1, 200 do
			for count = 1, 12 do
				local picked = PlacementLayout.pickTileIndices(36, count, Harness.fakeRandom(seed))
				expect(#picked).toBe(count)
				local seen = {}
				for _, index in picked do
					expect(index >= 1 and index <= 36).toBe(true)
					expect(seen[index]).toBe(nil)
					seen[index] = true
				end
			end
		end
	end)

	it("reuses tiles evenly when there are more players than tiles", function()
		local picked = PlacementLayout.pickTileIndices(4, 10, Harness.fakeRandom(5))
		expect(#picked).toBe(10)
		local uses = {}
		for _, index in picked do
			uses[index] = (uses[index] or 0) + 1
		end
		for index = 1, 4 do
			expect(uses[index] >= 2 and uses[index] <= 3).toBe(true)
		end
	end)

	it("varies with the seed", function()
		local a = PlacementLayout.pickTileIndices(36, 12, Harness.fakeRandom(1))
		local b = PlacementLayout.pickTileIndices(36, 12, Harness.fakeRandom(2))
		local same = true
		for i = 1, 12 do
			if a[i] ~= b[i] then
				same = false
			end
		end
		expect(same).toBe(false)
	end)

	it("errors with no tiles", function()
		expect(function()
			PlacementLayout.pickTileIndices(0, 2, Harness.fakeRandom(1))
		end).toThrow()
	end)
end)

describe("PlacementLayout.gridOffsets", function()
	it("lays 12 spawns out 4 wide and 3 deep, centred on the origin", function()
		local offsets = PlacementLayout.gridOffsets(12, 4, 6)
		expect(#offsets).toBe(12)
		local sumX, sumZ = 0, 0
		for _, offset in offsets do
			sumX += offset[1]
			sumZ += offset[2]
		end
		expect(sumX).toBeCloseTo(0)
		expect(sumZ).toBeCloseTo(0)
		expect(offsets[1][1]).toBeCloseTo(-9)
		expect(offsets[4][1]).toBeCloseTo(9)
		expect(offsets[1][2]).toBeCloseTo(-6)
		expect(offsets[12][2]).toBeCloseTo(6)
	end)
end)

describe("Config.Placement settling", function()
	it("holds a placed character long enough for the ground to replicate", function()
		-- The hold is what stops a player dropping through arena tiles their client has
		-- not received yet, which is how the first live test ended. Zero would turn it off.
		expect(Config.Placement.settleSeconds > 0).toBe(true)
	end)

	it("lets go again quickly enough to read as a hover, not a freeze", function()
		expect(Config.Placement.settleSeconds < 2).toBe(true)
	end)

	it("releases well before the round intro is over", function()
		-- Players are placed as the round intro starts, so the hold has to be over by the
		-- time they are expected to move.
		expect(Config.Placement.settleSeconds < Config.StateSeconds.RoundIntro).toBe(true)
	end)
end)
