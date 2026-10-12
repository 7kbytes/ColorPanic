local Harness = require("./harness")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local MotionRules = Harness.requireModule("ReplicatedStorage.Shared.MotionRules")

local FADE = 0.5

describe("MotionRules.glowAlpha", function()
	it("glows at full strength when the target never hides", function()
		expect(MotionRules.glowAlpha(100, nil, FADE)).toBe(1)
	end)

	it("glows at full strength while the reveal has time left", function()
		expect(MotionRules.glowAlpha(100, 103, FADE)).toBe(1)
	end)

	it("fades out across the last fadeSeconds of the reveal", function()
		expect(MotionRules.glowAlpha(100, 100 + FADE / 2, FADE)).toBe(0.5)
	end)

	it("is gone once the target has hidden", function()
		expect(MotionRules.glowAlpha(100, 100, FADE)).toBe(0)
		expect(MotionRules.glowAlpha(100, 99, FADE)).toBe(0)
	end)

	it("never fades when fadeSeconds is zero", function()
		expect(MotionRules.glowAlpha(100, 100.01, 0)).toBe(1)
		expect(MotionRules.glowAlpha(100, 100, 0)).toBe(0)
	end)
end)

describe("MotionRules.transparency", function()
	it("is the configured transparency at full strength", function()
		expect(MotionRules.transparency(1, 0.7)).toBe(0.7)
	end)

	it("is fully invisible at no strength", function()
		expect(MotionRules.transparency(0, 0.7)).toBe(1)
	end)

	it("clamps an alpha from outside 0 to 1", function()
		expect(MotionRules.transparency(2, 0.7)).toBe(0.7)
		expect(MotionRules.transparency(-1, 0.7)).toBe(1)
	end)
end)
