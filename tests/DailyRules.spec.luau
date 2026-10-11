local Harness = require("./harness")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local DailyRules = Harness.requireModule("ReplicatedStorage.Shared.DailyRules")
local DataRules = Harness.requireModule("ReplicatedStorage.Shared.DataRules")

local DAY = 86400
local TRACK = { 25, 40, 60, 80, 120, 180, 400 }

local function profileOn(lastClaimDay: number, streak: number, coins: number?)
	local profile = DataRules.defaultProfile()
	profile.lastClaimDay = lastClaimDay
	profile.streak = streak
	profile.coins = coins or 0
	return profile
end

describe("DailyRules.dayIndex", function()
	it("is the same all day and changes at midnight UTC", function()
		local midnight = 100 * DAY
		expect(DailyRules.dayIndex(midnight)).toBe(100)
		expect(DailyRules.dayIndex(midnight + DAY - 1)).toBe(100)
		expect(DailyRules.dayIndex(midnight + DAY)).toBe(101)
	end)

	it("only ever goes up", function()
		expect(DailyRules.dayIndex(200 * DAY) > DailyRules.dayIndex(199 * DAY)).toBe(true)
	end)
end)

describe("DailyRules.secondsUntilNextDay", function()
	it("is a full day at midnight and nearly nothing just before the next", function()
		expect(DailyRules.secondsUntilNextDay(100 * DAY)).toBe(DAY)
		expect(DailyRules.secondsUntilNextDay(100 * DAY + DAY - 1)).toBe(1)
	end)

	it("is never negative", function()
		expect(DailyRules.secondsUntilNextDay(0) >= 0).toBe(true)
	end)
end)

describe("DailyRules.canClaim", function()
	it("lets a new player claim", function()
		expect(DailyRules.canClaim(profileOn(0, 0), 100)).toBe(true)
	end)

	it("refuses a second claim the same day", function()
		-- The one that matters: pressing the button twice must not pay twice.
		expect(DailyRules.canClaim(profileOn(100, 1), 100)).toBe(false)
	end)

	it("lets them claim again the next day", function()
		expect(DailyRules.canClaim(profileOn(100, 1), 101)).toBe(true)
	end)

	it("refuses a claim dated in the future", function()
		-- Stored data ahead of the server clock, for example after a clock correction.
		-- It must not open an extra claim.
		expect(DailyRules.canClaim(profileOn(105, 3), 100)).toBe(false)
	end)
end)

describe("DailyRules.nextStreak", function()
	it("starts at 1 for a first claim", function()
		expect(DailyRules.nextStreak(profileOn(0, 0), 100)).toBe(1)
	end)

	it("continues when yesterday was claimed", function()
		expect(DailyRules.nextStreak(profileOn(99, 4), 100)).toBe(5)
	end)

	it("starts again when a day was missed", function()
		expect(DailyRules.nextStreak(profileOn(98, 9), 100)).toBe(1)
	end)

	it("starts again after a long absence", function()
		expect(DailyRules.nextStreak(profileOn(1, 30), 400)).toBe(1)
	end)
end)

describe("DailyRules.trackDay and rewardFor", function()
	it("walks up the track", function()
		expect(DailyRules.rewardFor(1, TRACK)).toBe(25)
		expect(DailyRules.rewardFor(7, TRACK)).toBe(400)
	end)

	it("repeats the track instead of running off the end", function()
		expect(DailyRules.trackDay(8, #TRACK)).toBe(1)
		expect(DailyRules.rewardFor(8, TRACK)).toBe(25)
		expect(DailyRules.rewardFor(14, TRACK)).toBe(400)
	end)

	it("copes with an empty track", function()
		expect(DailyRules.trackDay(3, 0)).toBe(0)
		expect(DailyRules.rewardFor(3, {})).toBe(0)
	end)

	it("treats a streak below 1 as the first day", function()
		expect(DailyRules.trackDay(0, #TRACK)).toBe(1)
	end)
end)

describe("DailyRules.claim", function()
	it("pays the coins and records the day", function()
		local result = DailyRules.claim(profileOn(0, 0, 10), 100, TRACK)
		expect(result.claimed).toBe(true)
		expect(result.coins).toBe(25)
		expect(result.profile.coins).toBe(35)
		expect(result.profile.lastClaimDay).toBe(100)
		expect(result.profile.streak).toBe(1)
	end)

	it("pays nothing on a second claim the same day", function()
		local claimed = DailyRules.claim(profileOn(0, 0, 10), 100, TRACK).profile
		local again = DailyRules.claim(claimed, 100, TRACK)
		expect(again.claimed).toBe(false)
		expect(again.coins).toBe(0)
		expect(again.profile.coins).toBe(claimed.coins)
	end)

	it("does not modify the profile it was given", function()
		local before = profileOn(0, 0, 10)
		DailyRules.claim(before, 100, TRACK)
		expect(before.coins).toBe(10)
		expect(before.lastClaimDay).toBe(0)
	end)

	it("builds a streak across seven days and pays the big one last", function()
		local profile = profileOn(0, 0, 0)
		local total = 0
		for day = 100, 106 do
			local result = DailyRules.claim(profile, day, TRACK)
			expect(result.claimed).toBe(true)
			profile = result.profile
			total += result.coins
		end
		expect(profile.streak).toBe(7)
		expect(total).toBe(25 + 40 + 60 + 80 + 120 + 180 + 400)
		expect(profile.coins).toBe(total)
	end)

	it("drops a broken streak back to the first reward", function()
		local profile = profileOn(0, 0, 0)
		for day = 100, 104 do
			profile = DailyRules.claim(profile, day, TRACK).profile
		end
		expect(profile.streak).toBe(5)
		-- Skips day 105 entirely.
		local result = DailyRules.claim(profile, 106, TRACK)
		expect(result.streak).toBe(1)
		expect(result.coins).toBe(25)
	end)

	it("leaves the other stats alone", function()
		local profile = profileOn(0, 0, 0)
		profile.wins = 3
		profile.roundsSurvived = 11
		profile.matchesPlayed = 7
		local result = DailyRules.claim(profile, 100, TRACK)
		expect(result.profile.wins).toBe(3)
		expect(result.profile.roundsSurvived).toBe(11)
		expect(result.profile.matchesPlayed).toBe(7)
	end)
end)

describe("DailyRules.view", function()
	it("offers tomorrow's reward when a claim is due", function()
		local view = DailyRules.view(profileOn(99, 4), 100 * DAY, TRACK)
		expect(view.canClaim).toBe(true)
		expect(view.streak).toBe(5)
		expect(view.reward).toBe(120)
	end)

	it("does not promise a reward already taken", function()
		-- After claiming, the panel shows the streak as it stands rather than advertising
		-- the next day's coins as if they were available now.
		local view = DailyRules.view(profileOn(100, 5), 100 * DAY, TRACK)
		expect(view.canClaim).toBe(false)
		expect(view.streak).toBe(5)
	end)

	it("counts down to the next day", function()
		local view = DailyRules.view(profileOn(100, 1), 100 * DAY + 3600, TRACK)
		expect(view.secondsUntilNext).toBe(DAY - 3600)
	end)
end)

describe("Daily fields travel with the profile", function()
	it("survives a save and load round trip", function()
		local claimed = DailyRules.claim(profileOn(0, 0, 0), 250, TRACK).profile
		local loaded = DataRules.sanitize(claimed)
		expect(loaded.lastClaimDay).toBe(250)
		expect(loaded.streak).toBe(1)
	end)

	it("defaults for a player saved before daily rewards existed", function()
		-- Old profiles in the DataStore have neither field.
		local old = { wins = 2, roundsSurvived = 5, matchesPlayed = 3, coins = 90 }
		local loaded = DataRules.sanitize(old)
		expect(loaded.lastClaimDay).toBe(0)
		expect(loaded.streak).toBe(0)
		expect(loaded.coins).toBe(90) -- and nothing else is lost
	end)

	it("changes the save signature, so a claim is actually written", function()
		local before = profileOn(0, 0, 0)
		local after = DailyRules.claim(before, 100, TRACK).profile
		expect(DataRules.signature(before) == DataRules.signature(after)).toBe(false)
	end)

	it("is carried through a rewards update", function()
		local profile = DailyRules.claim(profileOn(0, 0, 0), 100, TRACK).profile
		local afterWin = DataRules.recordMatchVictory(profile, 50)
		expect(afterWin.lastClaimDay).toBe(100)
		expect(afterWin.streak).toBe(1)
	end)

	it("is carried into the table ProfileStore saves", function()
		local profile = DailyRules.claim(profileOn(0, 0, 0), 100, TRACK).profile
		local target = DataRules.defaultProfile()
		DataRules.copyInto(target, profile)
		expect(target.lastClaimDay).toBe(100)
		expect(target.streak).toBe(1)
	end)
end)
