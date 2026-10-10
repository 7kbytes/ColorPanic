local Harness = require("./harness")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local LiveConfig = Harness.requireModule("ReplicatedStorage.Shared.Config")

-- These tests check RoundDirector against the SPEC section 5 curve, so they use that table
-- directly instead of whichever preset is active (the demo preset has its own table).
local SPEC_DIFFICULTY = {
	{ firstRound = 1, lastRound = 3, timerStart = 10, timerEnd = 8, colorCount = 3 },
	{ firstRound = 4, lastRound = 6, timerStart = 7, timerEnd = 6, colorCount = 4 },
	{ firstRound = 7, lastRound = 9, timerStart = 5, timerEnd = 5, colorCount = 5 },
	{ firstRound = 10, lastRound = nil, timerStart = 4, timerEnd = 4, colorCount = 6 },
}
local Config = table.clone(LiveConfig)
Config.Difficulty = SPEC_DIFFICULTY
local RoundDirector = Harness.requireModule("ServerScriptService.Server.RoundDirector")

describe("RoundDirector.getRow", function()
	local cases = {
		{ round = 1, firstRound = 1 },
		{ round = 3, firstRound = 1 },
		{ round = 4, firstRound = 4 },
		{ round = 6, firstRound = 4 },
		{ round = 7, firstRound = 7 },
		{ round = 9, firstRound = 7 },
		{ round = 10, firstRound = 10 },
		{ round = 50, firstRound = 10 },
	}
	for _, case in cases do
		local name =
			string.format("round %d uses the row starting at round %d", case.round, case.firstRound)
		it(name, function()
			expect(RoundDirector.getRow(Config.Difficulty, case.round).firstRound).toBe(
				case.firstRound
			)
		end)
	end

	it("errors for round 0", function()
		expect(function()
			RoundDirector.getRow(Config.Difficulty, 0)
		end).toThrow()
	end)
end)

describe("RoundDirector timer and color count", function()
	-- SPEC section 5: rounds 1 to 3 run 10s down to 8s, 4 to 6 run 7s to 6s,
	-- 7 to 9 run 5s, 10 and up run 4s.
	local expected = {
		{ timer = 10, colors = 3 },
		{ timer = 9, colors = 3 },
		{ timer = 8, colors = 3 },
		{ timer = 7, colors = 4 },
		{ timer = 6.5, colors = 4 },
		{ timer = 6, colors = 4 },
		{ timer = 5, colors = 5 },
		{ timer = 5, colors = 5 },
		{ timer = 5, colors = 5 },
		{ timer = 4, colors = 6 },
		{ timer = 4, colors = 6 },
	}
	for round, want in expected do
		local name =
			string.format("round %d: %ss, %d colors", round, tostring(want.timer), want.colors)
		it(name, function()
			local params = RoundDirector.getRoundParams(Config, round, 2, Harness.fakeRandom(round))
			expect(params.timerSeconds).toBeCloseTo(want.timer)
			expect(params.colorCount).toBe(want.colors)
			expect(#params.colorIds).toBe(want.colors)
		end)
	end
end)

describe("RoundDirector fairness rule", function()
	-- One target tile per two survivors, rounded up, never fewer than one.
	local expected = { [0] = 1, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6 }
	for survivors = 0, 12 do
		it(
			string.format("%d survivors need %d target tiles", survivors, expected[survivors]),
			function()
				local actual =
					RoundDirector.getMinTargetTiles(survivors, Config.Fairness.playersPerTargetTile)
				expect(actual).toBe(expected[survivors])
			end
		)
	end

	it("getRoundParams passes the fairness minimum through", function()
		local params = RoundDirector.getRoundParams(Config, 1, 7, Harness.fakeRandom(1))
		expect(params.minTargetTiles).toBe(4)
	end)
end)

describe("RoundDirector color choice", function()
	it(
		"picks distinct valid colors with the target among them, 200 seeds, rounds 1 to 12",
		function()
			local validIds = {}
			for _, colorDef in Config.Colors do
				validIds[colorDef.id] = true
			end
			for seed = 1, 200 do
				local round = (seed % 12) + 1
				local params =
					RoundDirector.getRoundParams(Config, round, 8, Harness.fakeRandom(seed))
				local seen = {}
				local targetFound = false
				for _, colorId in params.colorIds do
					expect(validIds[colorId]).toBe(true)
					expect(seen[colorId]).toBe(nil)
					seen[colorId] = true
					if colorId == params.targetColorId then
						targetFound = true
					end
				end
				expect(targetFound).toBe(true)
			end
		end
	)
end)

describe("RoundDirector reveal-then-hide", function()
	it("has no reveal in rounds 1 to 3 of the SPEC table", function()
		for round = 1, 3 do
			local params = RoundDirector.getRoundParams(Config, round, 2, Harness.fakeRandom(round))
			expect(params.revealSeconds).toBe(nil)
		end
	end)

	it("passes the row's reveal through", function()
		local fixture = table.clone(Config)
		fixture.Difficulty = {
			{ firstRound = 1, lastRound = 2, timerStart = 10, timerEnd = 10, colorCount = 3 },
			{
				firstRound = 3,
				lastRound = nil,
				timerStart = 9,
				timerEnd = 9,
				colorCount = 4,
				revealSeconds = 2,
			},
		}
		expect(RoundDirector.getRoundParams(fixture, 2, 2, Harness.fakeRandom(1)).revealSeconds).toBe(
			nil
		)
		expect(RoundDirector.getRoundParams(fixture, 3, 2, Harness.fakeRandom(1)).revealSeconds).toBe(
			2
		)
	end)
end)
