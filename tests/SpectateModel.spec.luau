local Harness = require("./harness")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local SpectateModel =
	Harness.requireModule("StarterPlayer.StarterPlayerScripts.Client.SpectateModel")

local ME = 1
local PLAYERS = {
	{ userId = ME, name = "Me", role = "Spectator" },
	{ userId = 2, name = "Sam", role = "Survivor" },
	{ userId = 3, name = "Alex", role = "Survivor" },
	{ userId = 4, name = "Kim", role = "Spectator" },
	{ userId = 5, name = "Lee", role = "Menu" },
	{ userId = 6, name = "Bo", role = "Survivor" },
}

local function ids(targets): { number }
	local list = {}
	for _, candidate in targets do
		table.insert(list, candidate.userId)
	end
	return list
end

describe("SpectateModel.targets", function()
	it("lists survivors other than me, sorted by name", function()
		local list = ids(SpectateModel.targets(PLAYERS, ME))
		expect(#list).toBe(3)
		expect(list[1]).toBe(3) -- Alex
		expect(list[2]).toBe(6) -- Bo
		expect(list[3]).toBe(2) -- Sam
	end)

	it("never lists me, even as a survivor", function()
		local players = { { userId = ME, name = "Me", role = "Survivor" } }
		expect(#SpectateModel.targets(players, ME)).toBe(0)
	end)

	it("breaks name ties by userId", function()
		local players = {
			{ userId = 9, name = "Twin", role = "Survivor" },
			{ userId = 8, name = "Twin", role = "Survivor" },
		}
		local list = ids(SpectateModel.targets(players, ME))
		expect(list[1]).toBe(8)
		expect(list[2]).toBe(9)
	end)
end)

describe("SpectateModel.pick and step", function()
	local targets = SpectateModel.targets(PLAYERS, ME) -- Alex 3, Bo 6, Sam 2

	it("starts with the first survivor", function()
		expect(SpectateModel.pick(targets, nil)).toBe(3)
	end)

	it("keeps watching someone who is still a survivor", function()
		expect(SpectateModel.pick(targets, 2)).toBe(2)
	end)

	it("moves on when the watched player is no longer a survivor", function()
		expect(SpectateModel.pick(targets, 4)).toBe(3)
	end)

	it("returns nil when nobody is left to watch", function()
		expect(SpectateModel.pick({}, 3)).toBe(nil)
		expect(SpectateModel.step({}, 3, 1)).toBe(nil)
	end)

	it("steps forward and wraps at the end", function()
		expect(SpectateModel.step(targets, 3, 1)).toBe(6)
		expect(SpectateModel.step(targets, 2, 1)).toBe(3)
	end)

	it("steps back and wraps at the start", function()
		expect(SpectateModel.step(targets, 3, -1)).toBe(2)
		expect(SpectateModel.step(targets, 6, -1)).toBe(3)
	end)

	it("stays put with a single survivor", function()
		local one = SpectateModel.targets({ { userId = 7, name = "Solo", role = "Survivor" } }, ME)
		expect(SpectateModel.step(one, 7, 1)).toBe(7)
		expect(SpectateModel.step(one, 7, -1)).toBe(7)
	end)
end)

describe("SpectateModel.card", function()
	it("says you are eliminated", function()
		expect(SpectateModel.card(3).title).toBe("Eliminated!")
	end)

	it("counts the rounds survived before the one you fell in", function()
		expect(SpectateModel.card(1).subtitle).toBe("Out in round 1")
		expect(SpectateModel.card(2).subtitle).toBe("You survived 1 round")
		expect(SpectateModel.card(5).subtitle).toBe("You survived 4 rounds")
	end)

	it("still has a subtitle without a round number", function()
		expect(SpectateModel.card(nil).subtitle).toBe("Better luck next time!")
	end)
end)
