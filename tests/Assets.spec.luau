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

describe("Util.displayName", function()
	it("names every palette color with its shape, capitalized", function()
		for _, colorDef in Config.Colors do
			local name = Util.displayName(colorDef)
			local shape = string.upper(string.sub(colorDef.shape, 1, 1))
				.. string.sub(colorDef.shape, 2)
			expect(name).toBe(colorDef.name .. " " .. shape)
		end
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

describe("Config.Assets sky", function()
	it("has six distinct skybox faces, or none at all", function()
		local sky = Config.Assets.Images.sky
		local faces = { sky.back, sky.down, sky.front, sky.left, sky.right, sky.up }
		if sky.front == 0 then
			for _, id in faces do
				expect(id).toBe(0)
			end
			return
		end
		local seen = {}
		for _, id in faces do
			expect(isAssetId(id)).toBe(true)
			expect(seen[id]).toBe(nil)
			seen[id] = true
		end
	end)
end)
