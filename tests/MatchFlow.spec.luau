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
