local Harness = require("./harness")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local Config = Harness.requireModule("ReplicatedStorage.Shared.Config")
local Util = Harness.requireModule("ReplicatedStorage.Shared.Util")
local RoundDirector = Harness.requireModule("ServerScriptService.Server.RoundDirector")

local function base()
	return {
		Match = { intermissionSeconds = 10, maxRounds = math.huge, minPlayers = 2 },
		StateSeconds = { RoundIntro = 3, Victory = 5 },
		Difficulty = {
			{ firstRound = 1, timerStart = 10 },
			{ firstRound = 2, timerStart = 8 },
		},
	}
end

describe("Util.applyOverrides", function()
	it("changes only the listed fields and keeps the rest", function()
		local config = Util.applyOverrides(base(), { Match = { intermissionSeconds = 5 } })
		expect(config.Match.intermissionSeconds).toBe(5)
		expect(config.Match.minPlayers).toBe(2)
		expect(config.Match.maxRounds).toBe(math.huge)
		expect(config.StateSeconds.RoundIntro).toBe(3)
	end)

	it("replaces lists whole", function()
		local config =
			Util.applyOverrides(base(), { Difficulty = { { firstRound = 1, timerStart = 14 } } })
		expect(#config.Difficulty).toBe(1)
		expect(config.Difficulty[1].timerStart).toBe(14)
	end)

	it("treats an empty table as no changes", function()
		local config = Util.applyOverrides(base(), { StateSeconds = {} })
		expect(config.StateSeconds.RoundIntro).toBe(3)
		expect(config.StateSeconds.Victory).toBe(5)
	end)

	it("errors on a key Config does not have", function()
		expect(function()
			Util.applyOverrides(base(), { Match = { intermisionSeconds = 5 } })
		end).toThrow()
	end)

	it("errors when the type does not match", function()
		expect(function()
			Util.applyOverrides(base(), { Match = { maxRounds = "8" } })
		end).toThrow()
	end)
end)

describe("Active preset", function()
	it("is a known preset", function()
		expect(Config.activePreset == "demo" or Config.activePreset == "normal").toBe(true)
	end)

	it("has a whole number round cap, or none", function()
		local cap = Config.Match.maxRounds
		expect(cap == math.huge or (cap >= 1 and cap == math.floor(cap))).toBe(true)
	end)

	-- The demo brief: a match lasts 3 to 4 minutes when everyone survives to the cap.
	if Config.activePreset == "demo" then
		it("demo match lasts 180 to 240 seconds if everyone survives to the cap", function()
			local states = Config.StateSeconds
			local seconds = Config.Match.intermissionSeconds + states.Victory + states.Reset
			for round = 1, Config.Match.maxRounds do
				local row = RoundDirector.getRow(Config.Difficulty, round)
				seconds += states.RoundIntro + RoundDirector.getTimerSeconds(row, round) + states.Elimination + states.RoundEnd
			end
			expect(seconds).toBeAtLeast(180)
			expect(seconds <= 240).toBe(true)
		end)
	end
end)
