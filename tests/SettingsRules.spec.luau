local Harness = require("./harness")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local DataRules = Harness.requireModule("ReplicatedStorage.Shared.DataRules")
local SettingsRules = Harness.requireModule("ReplicatedStorage.Shared.SettingsRules")

describe("SettingsRules.clampPercent", function()
	it("keeps a value already in range", function()
		expect(SettingsRules.clampPercent(0)).toBe(0)
		expect(SettingsRules.clampPercent(55)).toBe(55)
		expect(SettingsRules.clampPercent(100)).toBe(100)
	end)

	it("pulls anything out of range back in", function()
		expect(SettingsRules.clampPercent(-20)).toBe(0)
		expect(SettingsRules.clampPercent(10000)).toBe(100)
	end)

	it("defaults to full volume for anything that is not a number", function()
		-- This runs on data off the DataStore and on whatever a client sends, so nil,
		-- text and NaN all have to land somewhere sensible rather than erroring.
		expect(SettingsRules.clampPercent(nil)).toBe(100)
		expect(SettingsRules.clampPercent("loud")).toBe(100)
		expect(SettingsRules.clampPercent(0 / 0)).toBe(100)
		expect(SettingsRules.clampPercent({})).toBe(100)
	end)

	it("returns whole numbers", function()
		expect(SettingsRules.clampPercent(42.7)).toBe(42)
	end)
end)

describe("SettingsRules.step", function()
	it("moves by the step size", function()
		expect(SettingsRules.step(50, 1, 10)).toBe(60)
		expect(SettingsRules.step(50, -1, 10)).toBe(40)
	end)

	it("stops at the ends instead of wrapping", function()
		-- Wrapping from silent to full on one press would be a nasty surprise.
		expect(SettingsRules.step(0, -1, 10)).toBe(0)
		expect(SettingsRules.step(100, 1, 10)).toBe(100)
	end)

	it("can reach silence and full volume exactly", function()
		expect(SettingsRules.step(10, -1, 10)).toBe(0)
		expect(SettingsRules.step(90, 1, 10)).toBe(100)
	end)

	it("copes with a nonsense step size", function()
		expect(SettingsRules.step(50, 1, 0)).toBe(51)
		expect(SettingsRules.step(50, 1, -5)).toBe(51)
	end)
end)

describe("SettingsRules.scale", function()
	it("maps a percentage onto Roblox's 0 to 1 volume", function()
		expect(SettingsRules.scale(0)).toBe(0)
		expect(SettingsRules.scale(50)).toBe(0.5)
		expect(SettingsRules.scale(100)).toBe(1)
	end)
end)

describe("SettingsRules.label", function()
	it("says Off rather than 0%", function()
		expect(SettingsRules.label(0)).toBe("Off")
	end)

	it("shows a percentage otherwise", function()
		expect(SettingsRules.label(70)).toBe("70%")
		expect(SettingsRules.label(100)).toBe("100%")
	end)
end)

describe("SettingsRules.readRequest", function()
	it("reads a well formed request", function()
		local wanted = SettingsRules.readRequest({ music = 30, sfx = 80 })
		expect(wanted ~= nil).toBe(true)
		expect((wanted :: any).music).toBe(30)
		expect((wanted :: any).sfx).toBe(80)
	end)

	it("drops anything that is not a table", function()
		-- A client can send whatever it likes down a remote.
		expect(SettingsRules.readRequest(nil)).toBe(nil)
		expect(SettingsRules.readRequest("loud")).toBe(nil)
		expect(SettingsRules.readRequest(42)).toBe(nil)
	end)

	it("clamps silly values rather than refusing them", function()
		local wanted = SettingsRules.readRequest({ music = 9999, sfx = -5 })
		expect((wanted :: any).music).toBe(100)
		expect((wanted :: any).sfx).toBe(0)
	end)

	it("fills in missing fields at full volume", function()
		local wanted = SettingsRules.readRequest({})
		expect((wanted :: any).music).toBe(100)
		expect((wanted :: any).sfx).toBe(100)
	end)
end)

describe("SettingsRules.changed", function()
	it("sees a real change", function()
		expect(SettingsRules.changed(100, 100, 90, 100)).toBe(true)
		expect(SettingsRules.changed(100, 100, 100, 0)).toBe(true)
	end)

	it("ignores a request that changes nothing", function()
		-- Saving an unchanged profile costs DataStore budget for no reason.
		expect(SettingsRules.changed(50, 50, 50, 50)).toBe(false)
	end)

	it("compares after clamping, so 150 and 100 are the same request", function()
		expect(SettingsRules.changed(100, 50, 150, 50)).toBe(false)
	end)
end)

describe("Settings travel with the profile", function()
	it("starts a new player at full volume", function()
		local profile = DataRules.defaultProfile()
		expect(profile.musicPercent).toBe(100)
		expect(profile.sfxPercent).toBe(100)
	end)

	it("keeps a deliberate mute through a save and load", function()
		-- 0 is a real choice, not a missing value, and must not be read as "unset".
		local saved = DataRules.defaultProfile()
		saved.musicPercent = 0
		saved.sfxPercent = 20
		local loaded = DataRules.sanitize(saved)
		expect(loaded.musicPercent).toBe(0)
		expect(loaded.sfxPercent).toBe(20)
	end)

	it("defaults for a profile saved before settings existed", function()
		local old = { wins = 1, roundsSurvived = 2, matchesPlayed = 1, coins = 30 }
		local loaded = DataRules.sanitize(old)
		expect(loaded.musicPercent).toBe(100)
		expect(loaded.sfxPercent).toBe(100)
		expect(loaded.coins).toBe(30)
	end)

	it("repairs a stored value that is out of range", function()
		local broken = DataRules.defaultProfile()
		broken.musicPercent = 5000
		expect(DataRules.sanitize(broken).musicPercent).toBe(100)
	end)

	it("changes the save signature, so a settings change is written", function()
		local before = DataRules.defaultProfile()
		local after = DataRules.defaultProfile()
		after.musicPercent = 40
		expect(DataRules.signature(before) == DataRules.signature(after)).toBe(false)
	end)

	it("survives a match win and reaches the saved table", function()
		local profile = DataRules.defaultProfile()
		profile.musicPercent = 30
		profile.sfxPercent = 0
		local afterWin = DataRules.recordMatchVictory(profile, 50)
		expect(afterWin.musicPercent).toBe(30)
		expect(afterWin.sfxPercent).toBe(0)

		local target = DataRules.defaultProfile()
		DataRules.copyInto(target, afterWin)
		expect(target.musicPercent).toBe(30)
		expect(target.sfxPercent).toBe(0)
	end)
end)
