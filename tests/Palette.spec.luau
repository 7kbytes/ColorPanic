local fs = require("@lune/fs")
local serde = require("@lune/serde")

local Harness = require("./harness")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local Config = Harness.requireModule("ReplicatedStorage.Shared.Config")
local Util = Harness.requireModule("ReplicatedStorage.Shared.Util")

local PALETTE_PATH = "art/palette.json"
local SHAPES = { "heart", "triangle", "star", "circle", "square", "diamond" }

describe("Config.Colors palette rules", function()
	it("has exactly ids 1 to 6, in order", function()
		expect(#Config.Colors).toBe(6)
		for index, colorDef in Config.Colors do
			expect(colorDef.id).toBe(index)
		end
	end)

	it("has unique names", function()
		local seen = {}
		for _, colorDef in Config.Colors do
			expect(seen[colorDef.name]).toBe(nil)
			seen[colorDef.name] = true
		end
	end)

	it("has a well formed #RRGGBB hex for every color", function()
		for _, colorDef in Config.Colors do
			expect(string.match(colorDef.hex, "^#%x%x%x%x%x%x$") ~= nil).toBe(true)
		end
	end)

	it("pairs each of the six shapes with exactly one color", function()
		local count = {}
		for _, colorDef in Config.Colors do
			count[colorDef.shape] = (count[colorDef.shape] or 0) + 1
		end
		for _, shape in SHAPES do
			expect(count[shape]).toBe(1)
		end
	end)
end)

describe("Config.Colors matches art/palette.json", function()
	local palette = serde.decode("json", fs.readFile(PALETTE_PATH))

	it("has the same number of colors", function()
		expect(#palette.colors).toBe(#Config.Colors)
	end)

	it("has the same id, name, hex and shape for every color", function()
		for _, entry in palette.colors do
			local colorDef = Util.getColorDef(Config.Colors, entry.id)
			expect(colorDef ~= nil).toBe(true)
			expect(colorDef.name).toBe(entry.name)
			expect(string.upper(colorDef.hex)).toBe(string.upper(entry.hex))
			expect(colorDef.shape).toBe(entry.shape)
		end
	end)
end)

describe("Util.hexToRgb", function()
	it("converts #RRGGBB to three 0 to 255 values", function()
		local rgb = Util.hexToRgb("#E8383D")
		expect(rgb[1]).toBe(232)
		expect(rgb[2]).toBe(56)
		expect(rgb[3]).toBe(61)
	end)

	it("accepts lower case", function()
		expect(Util.hexToRgb("#ff8a1f")[1]).toBe(255)
	end)

	it("rejects anything that is not #RRGGBB", function()
		for _, bad in { "E8383D", "#E83", "#E8383DFF", "#GG0000", "" } do
			expect(function()
				Util.hexToRgb(bad)
			end).toThrow()
		end
	end)

	it("converts every palette color", function()
		for _, colorDef in Config.Colors do
			local rgb = Util.hexToRgb(colorDef.hex)
			for _, value in rgb do
				expect(value >= 0 and value <= 255).toBe(true)
			end
		end
	end)
end)

describe("Util.getColorDef", function()
	it("finds a color by id", function()
		expect(Util.getColorDef(Config.Colors, 3).name).toBe(Config.Colors[3].name)
	end)

	it("returns nil for an unknown id", function()
		expect(Util.getColorDef(Config.Colors, 99)).toBe(nil)
	end)
end)
