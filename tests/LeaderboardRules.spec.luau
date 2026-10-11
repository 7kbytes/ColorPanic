local Harness = require("./harness")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local LeaderboardRules = Harness.requireModule("ReplicatedStorage.Shared.LeaderboardRules")

local function entry(userId: number, name: string, wins: number)
	return { userId = userId, name = name, wins = wins }
end

describe("LeaderboardRules.rank", function()
	it("puts the most wins first", function()
		local rows = LeaderboardRules.rank({
			entry(1, "bea", 3),
			entry(2, "ash", 9),
			entry(3, "cal", 5),
		}, 10)
		expect(rows[1].name).toBe("ash")
		expect(rows[2].name).toBe("cal")
		expect(rows[3].name).toBe("bea")
	end)

	it("gives tied players the same place and skips the next", function()
		-- Two on 9 are both 2nd, so the next is 4th, the same way the results panel reads.
		local rows = LeaderboardRules.rank({
			entry(1, "ash", 12),
			entry(2, "bea", 9),
			entry(3, "cal", 9),
			entry(4, "dee", 4),
		}, 10)
		expect(rows[1].place).toBe(1)
		expect(rows[2].place).toBe(2)
		expect(rows[3].place).toBe(2)
		expect(rows[4].place).toBe(4)
	end)

	it("breaks ties the same way every refresh", function()
		-- The store's own order is not stable. Without a tiebreak the board would
		-- reshuffle every minute for no visible reason.
		local entries = { entry(2, "cal", 5), entry(1, "ash", 5), entry(3, "bea", 5) }
		local first = LeaderboardRules.rank(entries, 10)
		local shuffled = { entries[3], entries[1], entries[2] }
		local second = LeaderboardRules.rank(shuffled, 10)
		for index, row in first do
			expect(second[index].name).toBe(row.name)
		end
	end)

	it("keeps only the top N", function()
		local entries = {}
		for index = 1, 25 do
			table.insert(entries, entry(index, "p" .. index, index))
		end
		expect(#LeaderboardRules.rank(entries, 10)).toBe(10)
	end)

	it("copes with an empty board", function()
		expect(#LeaderboardRules.rank({}, 10)).toBe(0)
	end)

	it("does not modify the list it was given", function()
		local entries = { entry(1, "bea", 3), entry(2, "ash", 9) }
		LeaderboardRules.rank(entries, 10)
		expect(entries[1].name).toBe("bea")
	end)
end)

describe("LeaderboardRules.usable", function()
	it("drops players with no wins", function()
		local kept = LeaderboardRules.usable({ entry(1, "ash", 0), entry(2, "bea", 2) })
		expect(#kept).toBe(1)
		expect(kept[1].name).toBe("bea")
	end)

	it("drops entries whose name could not be resolved", function()
		-- A board showing a bare user id looks broken, so it shows nothing instead.
		local kept = LeaderboardRules.usable({ entry(1, "", 7), entry(2, "bea", 2) })
		expect(#kept).toBe(1)
		expect(kept[1].name).toBe("bea")
	end)
end)

describe("LeaderboardRules.shortName", function()
	it("leaves a name that fits", function()
		expect(LeaderboardRules.shortName("luxygee", 16)).toBe("luxygee")
	end)

	it("cuts a name that does not", function()
		local short = LeaderboardRules.shortName(string.rep("a", 30), 16)
		expect(#short < 30).toBe(true)
		expect(string.sub(short, -3)).toBe("...")
	end)

	it("does not cut a multi byte character in half", function()
		-- Cutting mid character would put a broken glyph on a public board.
		local name = string.rep("é", 20)
		local short = LeaderboardRules.shortName(name, 8)
		expect(utf8.len(short) ~= nil).toBe(true)
	end)

	it("copes with a zero length limit", function()
		expect(LeaderboardRules.shortName("luxygee", 0)).toBe("")
	end)
end)

describe("LeaderboardRules.rowText", function()
	it("reads as a place, a name and a score", function()
		local left, right = LeaderboardRules.rowText({ place = 1, name = "luxygee", wins = 12 }, 16)
		expect(string.find(left, "1%.") ~= nil).toBe(true)
		expect(string.find(left, "luxygee") ~= nil).toBe(true)
		expect(right).toBe("12")
	end)
end)

describe("LeaderboardRules.needsWrite", function()
	it("writes a player's first win", function()
		expect(LeaderboardRules.needsWrite(nil, 1)).toBe(true)
	end)

	it("writes when the total went up", function()
		expect(LeaderboardRules.needsWrite(3, 4)).toBe(true)
	end)

	it("skips a total that has not changed", function()
		expect(LeaderboardRules.needsWrite(4, 4)).toBe(false)
	end)

	it("never writes nobody with no wins", function()
		-- An all-time wins board should not be padded with zeroes.
		expect(LeaderboardRules.needsWrite(nil, 0)).toBe(false)
	end)

	it("ignores a total that went backwards", function()
		-- Wins only go up. A lower number means stale data, not a correction.
		expect(LeaderboardRules.needsWrite(9, 4)).toBe(false)
	end)
end)

describe("The board's place in the world", function()
	local Config = Harness.requireModule("ReplicatedStorage.Shared.Config")

	it("stands clear of the arena", function()
		-- The board is a solid part placed from a Config offset. Over the tile square it
		-- would be something to stand on during elimination, which is the one thing the
		-- builder rules forbid.
		local board = Config.Leaderboard
		local lobby = Config.Placement.lobbyOrigin
		local arena = Config.Arena.origin
		local x = lobby[1] + board.offset[1]
		local z = lobby[3] + board.offset[3]
		local keepOut = Config.Arena.gridSize * Config.Arena.tileSize / 2 + board.size[1]
		local clearX = math.abs(x - arena[1]) > keepOut
		local clearZ = math.abs(z - arena[3]) > keepOut
		expect(clearX or clearZ).toBe(true)
	end)

	it("sits above the lobby floor, not buried in it", function()
		expect(Config.Leaderboard.offset[2] > Config.Leaderboard.size[2] / 2 - 2).toBe(true)
	end)

	it("asks for no more rows than it draws", function()
		expect(Config.Leaderboard.topCount > 0).toBe(true)
		-- Roblox returns at most 100 per sorted page.
		expect(Config.Leaderboard.topCount <= 100).toBe(true)
	end)
end)
