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
	it("has six valid skybox faces, or none at all", function()
		local sky = Config.Assets.Images.sky
		local faces = { sky.back, sky.down, sky.front, sky.left, sky.right, sky.up }
		if sky.front == 0 then
			for _, id in faces do
				expect(id).toBe(0)
			end
			return
		end
		for _, id in faces do
			expect(isAssetId(id)).toBe(true)
		end
	end)

	-- The seamless scheme (tools/blender/prep_skybox.py) puts the same picture on back and
	-- front, and the same mirrored picture on left and right. Sharing one asset per pair
	-- means four textures in memory instead of six.
	it("shares one asset between back and front, and between left and right", function()
		local sky = Config.Assets.Images.sky
		if sky.front == 0 then
			return
		end
		expect(sky.back).toBe(sky.front)
		expect(sky.left).toBe(sky.right)
		expect(sky.up == sky.front).toBe(false)
		expect(sky.up == sky.left).toBe(false)
		expect(sky.down == sky.front).toBe(false)
	end)
end)

describe("Config.Assets loading art", function()
	it("is a valid asset ID, or 0 for the logo fallback", function()
		local art = Config.Assets.Images.loadingArt
		expect(art == 0 or isAssetId(art)).toBe(true)
	end)

	it("is not the same image as the logo", function()
		-- The loading screen falls back to the logo when there is no art. Pointing both at
		-- one asset would hide that fallback being broken.
		local images = Config.Assets.Images
		if images.loadingArt ~= 0 then
			expect(images.loadingArt == images.logo).toBe(false)
		end
	end)
end)

describe("Config.Assets menu tile art", function()
	local MENU_KEYS = { "menuDailyRewards", "menuLeaderboard", "menuShop", "menuSettings" }

	it("has a valid ID for every menu tile", function()
		for _, key in MENU_KEYS do
			expect(isAssetId(Config.Assets.Images[key])).toBe(true)
		end
	end)

	it("never points two tiles at the same image", function()
		-- Four IDs pasted by hand in one go: a copy and paste slip would silently put the
		-- wrong art on a button and still look deliberate.
		local seen = {}
		for _, key in MENU_KEYS do
			local id = Config.Assets.Images[key]
			expect(seen[id]).toBe(nil)
			seen[id] = key
		end
	end)

	it("does not reuse the Play or Leave art", function()
		local images = Config.Assets.Images
		for _, key in MENU_KEYS do
			expect(images[key] == images.play).toBe(false)
			expect(images[key] == images.leave).toBe(false)
		end
	end)

	it("has an aspect ratio for every tile, and a plausible one", function()
		-- The art is a wide pill. A tile taller than it is wide would mean the ratio was
		-- entered upside down.
		for _, ratio in Config.Menu.tileAspect do
			expect(ratio > 1).toBe(true)
			expect(ratio < 6).toBe(true)
		end
	end)
end)
