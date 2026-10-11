local Harness = require("./harness")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local CollisionRules = Harness.requireModule("ReplicatedStorage.Shared.CollisionRules")
local Config = Harness.requireModule("ReplicatedStorage.Shared.Config")

local RULES = Config.Props

describe("CollisionRules: what is solid", function()
	it("makes pillars, lamps, palms and the arch solid", function()
		for _, name in { "MarkerPillar", "LampPost", "PalmTree", "EntranceArch" } do
			expect(CollisionRules.isWalkThrough(name, RULES)).toBe(false)
			expect(#CollisionRules.collidersFor(name, 4, 10, 4, RULES) > 0).toBe(true)
		end
	end)

	it("leaves ground scatter walk-through", function()
		-- Ankle height rocks that stop you read as getting stuck, not as solidity.
		expect(CollisionRules.isWalkThrough("RocksAndFlowers", RULES)).toBe(true)
		expect(#CollisionRules.collidersFor("RocksAndFlowers", 6, 1, 6, RULES)).toBe(0)
	end)

	it("leaves the islands, pads and clouds alone, since they carry their own collision", function()
		for _, name in { "IslandBase", "IslandTop", "CentralPlatform", "SpawnPad", "Cloud" } do
			expect(#CollisionRules.collidersFor(name, 40, 20, 40, RULES)).toBe(0)
		end
	end)

	it("ignores a prop with no height", function()
		expect(#CollisionRules.collidersFor("PalmTree", 4, 0, 4, RULES)).toBe(0)
	end)
end)

describe("CollisionRules: upright posts", function()
	it("gives a palm a narrow trunk, not its full spread", function()
		-- The mesh is wide because of the fronds. Blocking that width would stop players
		-- several studs from the trunk.
		local colliders = CollisionRules.collidersFor("PalmTree", 12, 18, 12, RULES)
		expect(#colliders).toBe(1)
		expect(colliders[1].kind).toBe("cylinder")
		expect(colliders[1].width < 4).toBe(true)
		expect(colliders[1].height).toBe(18) -- full height, so you cannot walk over it
	end)

	it("never makes a trunk wider than the prop itself", function()
		local colliders = CollisionRules.collidersFor("LampPost", 0.8, 10, 0.8, RULES)
		expect(colliders[1].width <= 0.8).toBe(true)
	end)

	it("centres the post on the prop", function()
		local colliders = CollisionRules.collidersFor("LampPost", 3, 10, 3, RULES)
		expect(colliders[1].offsetX).toBe(0)
		expect(colliders[1].offsetZ).toBe(0)
	end)
end)

describe("CollisionRules: the arch", function()
	it("puts a post down each side and leaves the middle open", function()
		local colliders = CollisionRules.collidersFor("EntranceArch", 20, 14, 4, RULES)
		expect(#colliders).toBe(2)
		expect(colliders[1].offsetX == -colliders[2].offsetX).toBe(true)
		expect(colliders[1].offsetX ~= 0).toBe(true)
	end)

	it("leaves a gap wide enough to walk through", function()
		local colliders = CollisionRules.collidersFor("EntranceArch", 20, 14, 4, RULES)
		local inner = math.abs(colliders[1].offsetX) - colliders[1].width / 2
		local gap = inner * 2
		-- A character is about 4 studs wide at the shoulders.
		expect(gap > 5).toBe(true)
	end)

	it("keeps both posts inside the arch", function()
		local colliders = CollisionRules.collidersFor("EntranceArch", 20, 14, 4, RULES)
		for _, post in colliders do
			local outer = math.abs(post.offsetX) + post.width / 2
			expect(outer <= 10).toBe(true)
		end
	end)
end)

describe("CollisionRules: solid blocks", function()
	it("fills a pillar's footprint, pulled in a little", function()
		local colliders = CollisionRules.collidersFor("MarkerPillar", 5, 12, 5, RULES)
		expect(#colliders).toBe(1)
		expect(colliders[1].kind).toBe("box")
		expect(colliders[1].width < 5).toBe(true)
		expect(colliders[1].width > 3).toBe(true)
		expect(colliders[1].height).toBe(12)
	end)

	it("never inverts the footprint of a prop narrower than the inset", function()
		local colliders = CollisionRules.collidersFor("MarkerPillar", 0.2, 12, 0.2, RULES)
		expect(colliders[1].width > 0).toBe(true)
		expect(colliders[1].depth > 0).toBe(true)
	end)
end)
