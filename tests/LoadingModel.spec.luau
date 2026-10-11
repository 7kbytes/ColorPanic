local Harness = require("./harness")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local LoadingModel = Harness.requireModule("ReplicatedStorage.Shared.LoadingModel")

describe("LoadingModel.progress", function()
	it("runs from nothing to everything", function()
		expect(LoadingModel.progress(0, 40)).toBe(0)
		expect(LoadingModel.progress(20, 40)).toBe(0.5)
		expect(LoadingModel.progress(40, 40)).toBe(1)
	end)

	it("treats an empty list as finished rather than dividing by zero", function()
		expect(LoadingModel.progress(0, 0)).toBe(1)
	end)

	it("never reports outside 0 to 1", function()
		expect(LoadingModel.progress(50, 40)).toBe(1)
		expect(LoadingModel.progress(-5, 40)).toBe(0)
	end)
end)

describe("LoadingModel.percentText", function()
	it("reads as a percentage", function()
		expect(LoadingModel.percentText(0, 40)).toBe("0%")
		expect(LoadingModel.percentText(10, 40)).toBe("25%")
		expect(LoadingModel.percentText(40, 40)).toBe("100%")
	end)

	it("does not show 100% before everything is done", function()
		-- Rounding up at 99.6% would say 100% with an asset still outstanding.
		local text = LoadingModel.percentText(39, 40)
		expect(text == "100%").toBe(false)
	end)
end)

describe("LoadingModel.tipAt", function()
	it("starts on the first tip", function()
		expect(LoadingModel.tipAt(0, 3.5)).toBe(LoadingModel.TIPS[1])
	end)

	it("moves on after the interval", function()
		expect(LoadingModel.tipAt(4, 3.5)).toBe(LoadingModel.TIPS[2])
	end)

	it("cycles rather than running off the end", function()
		local count = #LoadingModel.TIPS
		expect(LoadingModel.tipAt(3.5 * count, 3.5)).toBe(LoadingModel.TIPS[1])
		expect(LoadingModel.tipAt(3.5 * (count + 1), 3.5)).toBe(LoadingModel.TIPS[2])
	end)

	it("copes with a zero interval and with negative time", function()
		expect(LoadingModel.tipAt(10, 0)).toBe(LoadingModel.TIPS[1])
		expect(LoadingModel.tipAt(-5, 3.5)).toBe(LoadingModel.TIPS[1])
	end)
end)

describe("LoadingModel.canClose", function()
	it("closes once everything is ready and the minimum has passed", function()
		expect(LoadingModel.canClose(true, true, 3, 2)).toBe(true)
	end)

	it("waits for the game to load", function()
		expect(LoadingModel.canClose(false, true, 3, 2)).toBe(false)
	end)

	it("waits for preloading", function()
		expect(LoadingModel.canClose(true, false, 3, 2)).toBe(false)
	end)

	it("holds for the minimum so the screen cannot flash", function()
		-- A fast rejoin loads almost instantly, and a screen appearing and vanishing in
		-- two frames reads as a glitch.
		expect(LoadingModel.canClose(true, true, 0.1, 2)).toBe(false)
		expect(LoadingModel.canClose(true, true, 2, 2)).toBe(true)
	end)
end)

describe("LoadingModel.preloadTimedOut", function()
	it("gives up once the deadline passes", function()
		expect(LoadingModel.preloadTimedOut(21, 20)).toBe(true)
		expect(LoadingModel.preloadTimedOut(19, 20)).toBe(false)
	end)

	it("never times out when the deadline is off", function()
		expect(LoadingModel.preloadTimedOut(9999, 0)).toBe(false)
	end)
end)
