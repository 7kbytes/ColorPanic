local Harness = require("./harness")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local ResultsModel = Harness.requireModule("StarterPlayer.StarterPlayerScripts.Client.ResultsModel")

local function standing(
	userId: number,
	name: string,
	place: number?,
	rounds: number,
	extra: { [string]: any }?
)
	local s = {
		userId = userId,
		name = name,
		place = place,
		roundsSurvived = rounds,
		winner = place == 1,
		left = false,
	}
	for key, value in extra or {} do
		s[key] = value
	end
	return s
end

local function result(winners: { string }, standings, rounds: number)
	return { winnerUserIds = {}, winnerNames = winners, standings = standings, rounds = rounds }
end

describe("ResultsModel.ordinal", function()
	it("uses the right suffix, including the teens", function()
		local cases = {
			[1] = "1st",
			[2] = "2nd",
			[3] = "3rd",
			[4] = "4th",
			[11] = "11th",
			[12] = "12th",
			[13] = "13th",
			[21] = "21st",
			[22] = "22nd",
			[23] = "23rd",
			[101] = "101st",
			[111] = "111th",
		}
		for n, text in cases do
			expect(ResultsModel.ordinal(n)).toBe(text)
		end
	end)
end)

describe("ResultsModel.view", function()
	local two = result({ "Alex" }, { standing(1, "Alex", 1, 5), standing(2, "Sam", 2, 1) }, 5)

	it("names a single winner", function()
		local view = ResultsModel.view(two, 2, 6)
		expect(view.title).toBe("Winner!")
		expect(view.subtitle).toBe("Alex · Match lasted 5 rounds")
	end)

	it("calls a shared win", function()
		local shared = result({ "A", "B" }, { standing(1, "A", 1, 8), standing(2, "B", 1, 8) }, 8)
		expect(ResultsModel.view(shared, 1, 6).title).toBe("Shared win!")
	end)

	it("formats each row and highlights the local player", function()
		local view = ResultsModel.view(two, 2, 6)
		expect(view.rows[1].place).toBe("1st")
		expect(view.rows[1].detail).toBe("5 rounds")
		expect(view.rows[1].isSelf).toBe(false)
		expect(view.rows[2].place).toBe("2nd")
		expect(view.rows[2].detail).toBe("1 round")
		expect(view.rows[2].isSelf).toBe(true)
	end)

	it("shows a player who left without a place", function()
		local withLeaver = result(
			{ "Alex" },
			{ standing(1, "Alex", 1, 3), standing(3, "Kim", nil, 1, { left = true }) },
			3
		)
		local row = ResultsModel.view(withLeaver, 1, 6).rows[2]
		expect(row.place).toBe("-")
		expect(row.detail).toBe("left")
	end)

	it("says 1 round for a one-round match", function()
		local short = result({ "A" }, { standing(1, "A", 1, 1) }, 1)
		expect(ResultsModel.view(short, 1, 6).subtitle).toBe("A · Match lasted 1 round")
	end)

	it("lists at most maxRows and counts the rest", function()
		local standings = {}
		for i = 1, 9 do
			table.insert(standings, standing(i, "P" .. i, i, 9 - i))
		end
		local view = ResultsModel.view(result({ "P1" }, standings, 9), 1, 6)
		expect(#view.rows).toBe(6)
		expect(view.more).toBe(3)
	end)

	it("keeps the local player's row in view when they are below the cut", function()
		local standings = {}
		for i = 1, 9 do
			table.insert(standings, standing(i, "P" .. i, i, 9 - i))
		end
		local view = ResultsModel.view(result({ "P1" }, standings, 9), 8, 6)
		expect(view.rows[6].name).toBe("P8")
		expect(view.rows[6].isSelf).toBe(true)
		expect(view.rows[6].place).toBe("8th")
	end)

	it("says Match over with no winners", function()
		expect(ResultsModel.view(result({}, {}, 3), 1, 6).title).toBe("Match over")
	end)
end)
