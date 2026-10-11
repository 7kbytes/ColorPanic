local Harness = require("./harness")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local DataRules = Harness.requireModule("ReplicatedStorage.Shared.DataRules")

describe("DataRules.defaultProfile", function()
	it("initializes all stats to zero", function()
		local profile = DataRules.defaultProfile()
		expect(profile.wins).toBe(0)
		expect(profile.roundsSurvived).toBe(0)
		expect(profile.matchesPlayed).toBe(0)
		expect(profile.coins).toBe(0)
	end)
end)

describe("DataRules.sanitize", function()
	it("returns default profile for non-table input", function()
		local p1 = DataRules.sanitize(nil)
		expect(p1.wins).toBe(0)
		expect(p1.coins).toBe(0)

		local p2 = DataRules.sanitize("string")
		expect(p2.matchesPlayed).toBe(0)
	end)

	it("keeps valid integer values", function()
		local raw = {
			wins = 5,
			roundsSurvived = 22,
			matchesPlayed = 10,
			coins = 150,
		}
		local profile = DataRules.sanitize(raw)
		expect(profile.wins).toBe(5)
		expect(profile.roundsSurvived).toBe(22)
		expect(profile.matchesPlayed).toBe(10)
		expect(profile.coins).toBe(150)
	end)

	it("floors decimals and defaults missing or negative fields", function()
		local raw = {
			wins = 3.8,
			roundsSurvived = -4,
			coins = "invalid",
		}
		local profile = DataRules.sanitize(raw)
		expect(profile.wins).toBe(3)
		expect(profile.roundsSurvived).toBe(0)
		expect(profile.matchesPlayed).toBe(0)
		expect(profile.coins).toBe(0)
	end)
end)

describe("DataRules.recordRoundSurvived", function()
	it("increments rounds survived and awards coins", function()
		local profile = DataRules.defaultProfile()
		local updated = DataRules.recordRoundSurvived(profile, 5)
		expect(updated.roundsSurvived).toBe(1)
		expect(updated.coins).toBe(5)
		expect(updated.wins).toBe(0)
		expect(updated.matchesPlayed).toBe(0)
	end)

	it("ignores negative coins", function()
		local profile = DataRules.defaultProfile()
		local updated = DataRules.recordRoundSurvived(profile, -10)
		expect(updated.roundsSurvived).toBe(1)
		expect(updated.coins).toBe(0)
	end)
end)

describe("DataRules.recordMatchVictory", function()
	it("increments wins and awards win coins", function()
		local profile = DataRules.defaultProfile()
		local updated = DataRules.recordMatchVictory(profile, 50)
		expect(updated.wins).toBe(1)
		expect(updated.coins).toBe(50)
		expect(updated.roundsSurvived).toBe(0)
	end)
end)

describe("DataRules.recordMatchPlayed", function()
	it("increments matches played without changing other stats", function()
		local profile = DataRules.defaultProfile()
		local updated = DataRules.recordMatchPlayed(profile)
		expect(updated.matchesPlayed).toBe(1)
		expect(updated.wins).toBe(0)
		expect(updated.coins).toBe(0)
	end)
end)

describe("DataRules.canAfford and deductCoins", function()
	it("checks affordability correctly", function()
		local profile = {
			wins = 0,
			roundsSurvived = 0,
			matchesPlayed = 0,
			coins = 30,
		}
		expect(DataRules.canAfford(profile, 20)).toBe(true)
		expect(DataRules.canAfford(profile, 30)).toBe(true)
		expect(DataRules.canAfford(profile, 31)).toBe(false)
		expect(DataRules.canAfford(profile, -5)).toBe(false)
	end)

	it("deducts coins when affordable", function()
		local profile = {
			wins = 0,
			roundsSurvived = 0,
			matchesPlayed = 0,
			coins = 50,
		}
		local success, updated = DataRules.deductCoins(profile, 20)
		expect(success).toBe(true)
		expect(updated.coins).toBe(30)
		expect(profile.coins).toBe(50) -- original is unchanged
	end)

	it("refuses deduction when coins are insufficient", function()
		local profile = {
			wins = 0,
			roundsSurvived = 0,
			matchesPlayed = 0,
			coins = 10,
		}
		local success, updated = DataRules.deductCoins(profile, 25)
		expect(success).toBe(false)
		expect(updated.coins).toBe(10)
	end)
end)

describe("DataRules.signature", function()
	local base = { wins = 2, roundsSurvived = 7, matchesPlayed = 3, coins = 105 }

	it("is the same for the same values", function()
		expect(DataRules.signature(base)).toBe(DataRules.signature(table.clone(base)))
	end)

	it("changes when any saved field changes", function()
		local original = DataRules.signature(base)
		for _, field in { "wins", "roundsSurvived", "matchesPlayed", "coins" } do
			local changed = table.clone(base)
			changed[field] += 1
			expect(DataRules.signature(changed) == original).toBe(false)
		end
	end)

	it("does not confuse two fields swapping values", function()
		local swapped = table.clone(base)
		swapped.wins = base.roundsSurvived
		swapped.roundsSurvived = base.wins
		expect(DataRules.signature(swapped) == DataRules.signature(base)).toBe(false)
	end)
end)
