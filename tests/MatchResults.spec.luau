local Harness = require("./harness")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local MatchResults = Harness.requireModule("ServerScriptService.Server.MatchResults")

local function out(userId: number, name: string, round: number, left: boolean?)
	return { userId = userId, name = name, round = round, left = left == true }
end

local function find(standings, userId: number)
	for _, standing in standings do
		if standing.userId == userId then
			return standing
		end
	end
	error("no standing for " .. userId)
end

describe("MatchResults.build", function()
	it("puts a single winner first with every round played", function()
		local standings = MatchResults.build(
			{ { userId = 1, name = "Alex" } },
			{ out(2, "Sam", 3) },
			5
		)
		expect(standings[1].userId).toBe(1)
		expect(standings[1].place).toBe(1)
		expect(standings[1].winner).toBe(true)
		expect(standings[1].roundsSurvived).toBe(5)
		expect(standings[2].place).toBe(2)
		expect(standings[2].roundsSurvived).toBe(2)
	end)

	it("ranks later eliminations higher and shares a place within a round", function()
		local standings = MatchResults.build({ { userId = 1, name = "Win" } }, {
			out(2, "Early", 1),
			out(3, "Late", 4),
			out(4, "MidA", 2),
			out(5, "MidB", 2),
		}, 5)
		expect(find(standings, 3).place).toBe(2)
		expect(find(standings, 4).place).toBe(3)
		expect(find(standings, 5).place).toBe(3)
		expect(find(standings, 2).place).toBe(5)
		expect(find(standings, 2).roundsSurvived).toBe(0)
		-- Order: winner, Late, MidA, MidB (by name), Early.
		local order = {}
		for _, standing in standings do
			table.insert(order, standing.name)
		end
		expect(table.concat(order, ",")).toBe("Win,Late,MidA,MidB,Early")
	end)

	it("gives every shared winner 1st place, sorted by name", function()
		local standings = MatchResults.build({
			{ userId = 7, name = "Zed" },
			{ userId = 8, name = "Amy" },
		}, { out(9, "Out", 2) }, 8)
		expect(standings[1].name).toBe("Amy")
		expect(standings[2].name).toBe("Zed")
		expect(standings[1].place).toBe(1)
		expect(standings[2].place).toBe(1)
		expect(standings[3].place).toBe(3)
	end)

	it("lists players who left last, without a place", function()
		local standings = MatchResults.build({ { userId = 1, name = "Win" } }, {
			out(2, "Quit", 3, true),
			out(3, "Lost", 1),
		}, 4)
		local last = standings[#standings]
		expect(last.name).toBe("Quit")
		expect(last.left).toBe(true)
		expect(last.place).toBe(nil)
		expect(last.roundsSurvived).toBe(2)
		expect(find(standings, 3).place).toBe(2)
	end)

	it("copes with no eliminations", function()
		local standings = MatchResults.build(
			{ { userId = 1, name = "A" }, { userId = 2, name = "B" } },
			{},
			8
		)
		expect(#standings).toBe(2)
	end)
end)
