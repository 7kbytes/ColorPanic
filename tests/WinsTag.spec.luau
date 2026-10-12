local Harness = require("./harness")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local Config = Harness.requireModule("ReplicatedStorage.Shared.Config")
local Util = Harness.requireModule("ReplicatedStorage.Shared.Util")

local TAG = Config.WinsTag

describe("Util.winsLabel", function()
	it("counts one win in the singular", function()
		expect(Util.winsLabel(1, TAG)).toBe("1 win")
	end)

	it("counts anything else in the plural", function()
		expect(Util.winsLabel(2, TAG)).toBe("2 wins")
		expect(Util.winsLabel(57, TAG)).toBe("57 wins")
	end)

	it("draws nothing for a player who has not won yet", function()
		expect(Util.winsLabel(0, TAG)).toBe(nil)
	end)

	it("draws the zero when the config asks for it", function()
		local showing = { showZero = true, oneFormat = TAG.oneFormat, manyFormat = TAG.manyFormat }
		expect(Util.winsLabel(0, showing)).toBe("0 wins")
	end)

	it("treats a negative count as none, rather than announcing it", function()
		-- Nothing should ever send a negative, but a bug upstream should not put "-3 wins"
		-- over someone's head.
		expect(Util.winsLabel(-3, TAG)).toBe(nil)
	end)

	it("ignores a fraction, so a count can never render as 2.5", function()
		expect(Util.winsLabel(2.7, TAG)).toBe("2 wins")
	end)
end)

describe("Config.WinsTag", function()
	it("sits above the head rather than inside it", function()
		expect(TAG.studsAboveHead > 0).toBe(true)
	end)

	it("has a readable size and text", function()
		expect(TAG.sizePixels[1] > 0).toBe(true)
		expect(TAG.sizePixels[2] > 0).toBe(true)
		expect(TAG.textSize > 0).toBe(true)
		-- The billboard does not scale its text, so a size taller than the board would be
		-- clipped.
		expect(TAG.textSize <= TAG.sizePixels[2]).toBe(true)
	end)

	it("stops drawing tags at some distance, so the arena stays readable", function()
		expect(TAG.maxDistanceStuds > 0).toBe(true)
	end)

	it("has a place for the count in both formats", function()
		expect(string.find(TAG.oneFormat, "%%d") ~= nil).toBe(true)
		expect(string.find(TAG.manyFormat, "%%d") ~= nil).toBe(true)
	end)
end)
