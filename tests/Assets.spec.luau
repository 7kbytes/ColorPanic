local Harness = require("./harness")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local Config = Harness.requireModule("ReplicatedStorage.Shared.Config")
local Util = Harness.requireModule("ReplicatedStorage.Shared.Util")

local function isAssetId(value: any): boolean
	return type(value) == "number" and value > 0 and value == math.floor(value)
end

describe("Config.Assets", function()
	it("has tile art and a shape icon for every palette shape", function()
		for _, colorDef in Config.Colors do
			expect(isAssetId(Config.Assets.Images.shapeTile[colorDef.shape])).toBe(true)
			expect(isAssetId(Config.Assets.Images.shapeIcon[colorDef.shape])).toBe(true)
		end
	end)

	it("never reuses an image ID for two different assets", function()
		local seen = {}
		local function check(id: number)
			expect(seen[id]).toBe(nil)
			seen[id] = true
		end
		local images = Config.Assets.Images
		for _, colorDef in Config.Colors do
			check(images.shapeTile[colorDef.shape])
			check(images.shapeIcon[colorDef.shape])
		end
		check(images.crown)
		check(images.player)
		check(images.stopwatch)
	end)
end)

describe("Util.getTileImageId", function()
	it("finds each color's tile art through its shape", function()
		for _, colorDef in Config.Colors do
			expect(Util.getTileImageId(Config.Colors, Config.Assets.Images.shapeTile, colorDef.id)).toBe(
				Config.Assets.Images.shapeTile[colorDef.shape]
			)
		end
	end)

	it("returns nil for an unknown color", function()
		expect(Util.getTileImageId(Config.Colors, Config.Assets.Images.shapeTile, 99)).toBe(nil)
	end)

	it("returns nil when the art has no ID yet", function()
		local shapeTiles = table.clone(Config.Assets.Images.shapeTile)
		local first = Config.Colors[1]
		shapeTiles[first.shape] = 0
		expect(Util.getTileImageId(Config.Colors, shapeTiles, first.id)).toBe(nil)
	end)
end)
