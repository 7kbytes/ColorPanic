local Harness = require("./harness")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local MatchFlow = Harness.requireModule("ServerScriptService.Server.MatchFlow")

local function ctx(players: number, survivors: number)
	return { playerCount = players, survivorCount = survivors, minPlayers = 2 }
end

describe("MatchFlow.nextState", function()
	local cases = {
		{ "Lobby", ctx(1, 0), "Lobby" },
		{ "Lobby", ctx(2, 0), "Intermission" },
		{ "Intermission", ctx(1, 0), "Lobby" },
		{ "Intermission", ctx(2, 0), "RoundIntro" },
		{ "RoundIntro", ctx(2, 2), "Run" },
		{ "Run", ctx(2, 2), "Elimination" },
		{ "Elimination", ctx(2, 2), "RoundEnd" },
		{ "RoundEnd", ctx(3, 2), "RoundIntro" },
		{ "RoundEnd", ctx(3, 1), "Victory" },
		{ "Victory", ctx(3, 1), "Reset" },
		{ "Reset", ctx(3, 0), "Lobby" },
		-- Every participant left: skip to Reset from any in-match state.
		{ "RoundIntro", ctx(1, 0), "Reset" },
		{ "Run", ctx(1, 0), "Reset" },
		{ "Elimination", ctx(1, 0), "Reset" },
		{ "RoundEnd", ctx(1, 0), "Reset" },
	}
	for _, case in cases do
		local from, context, to = case[1], case[2], case[3]
		local name = string.format(
			"%s with %d players, %d survivors -> %s",
			from,
			context.playerCount,
			context.survivorCount,
			to
		)
		it(name, function()
			expect(MatchFlow.nextState(from, context)).toBe(to)
		end)
	end
end)

describe("MatchFlow.nextState shared win", function()
	it("RoundEnd goes to Victory on a shared win even with several survivors", function()
		local context = { playerCount = 3, survivorCount = 3, minPlayers = 2, sharedWin = true }
		expect(MatchFlow.nextState("RoundEnd", context)).toBe("Victory")
	end)

	it("RoundEnd still loops when sharedWin is false", function()
		local context = { playerCount = 3, survivorCount = 3, minPlayers = 2, sharedWin = false }
		expect(MatchFlow.nextState("RoundEnd", context)).toBe("RoundIntro")
	end)
end)

describe("MatchFlow.nextState round cap", function()
	local function capCtx(survivors: number, round: number, maxRounds: number?)
		return {
			playerCount = 4,
			survivorCount = survivors,
			minPlayers = 2,
			round = round,
			maxRounds = maxRounds,
		}
	end

	it("loops before the last round", function()
		expect(MatchFlow.nextState("RoundEnd", capCtx(3, 7, 8))).toBe("RoundIntro")
	end)

	it("goes to Victory after the last round with several survivors (shared win)", function()
		expect(MatchFlow.nextState("RoundEnd", capCtx(3, 8, 8))).toBe("Victory")
	end)

	it("goes to Victory after the last round even if a replay was pending", function()
		-- Everyone fell in the last round: survivors are unchanged, the cap still ends it.
		expect(MatchFlow.nextState("RoundEnd", capCtx(2, 8, 8))).toBe("Victory")
	end)

	it("never caps when maxRounds is math.huge or missing", function()
		expect(MatchFlow.nextState("RoundEnd", capCtx(3, 50, math.huge))).toBe("RoundIntro")
		expect(MatchFlow.nextState("RoundEnd", capCtx(3, 50, nil))).toBe("RoundIntro")
	end)

	it("does not affect other states", function()
		expect(MatchFlow.nextState("Run", capCtx(3, 8, 8))).toBe("Elimination")
		expect(MatchFlow.nextState("Elimination", capCtx(3, 8, 8))).toBe("RoundEnd")
	end)
end)
