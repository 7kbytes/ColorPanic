local Harness = require("./harness")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local Broadcast = Harness.requireModule("ServerScriptService.Server.Broadcast")

local function indexOf(list: { string }, item: string): number
	return table.find(list, item) or error(item .. " is not sent")
end

describe("Broadcast order", function()
	it("sends the round and target before the RoundIntro state (#17)", function()
		local order = Broadcast.onTransition("RoundIntro")
		expect(indexOf(order, "RoundInfo") < indexOf(order, "StateChanged")).toBe(true)
		expect(indexOf(order, "Target") < indexOf(order, "StateChanged")).toBe(true)
		expect(indexOf(order, "RoundInfo") < indexOf(order, "Target")).toBe(true)
	end)

	it("sends the winners before the Victory state", function()
		local order = Broadcast.onTransition("Victory")
		expect(indexOf(order, "MatchResult") < indexOf(order, "StateChanged")).toBe(true)
	end)

	it("reveals the target only after Run has started", function()
		local order = Broadcast.onTransition("Run")
		expect(indexOf(order, "StateChanged") < indexOf(order, "Reveal")).toBe(true)
	end)

	it("sends only the state for the other states", function()
		for _, state in { "Lobby", "Intermission", "Elimination", "RoundEnd", "Reset" } do
			local order = Broadcast.onTransition(state)
			expect(#order).toBe(1)
			expect(order[1]).toBe("StateChanged")
		end
	end)

	it("brings a joiner up to date with the state last", function()
		local order = Broadcast.onJoin()
		expect(order[#order]).toBe("StateChanged")
		for _, message in { "MatchResult", "RoundInfo", "Target" } do
			expect(indexOf(order, message) < #order).toBe(true)
		end
		expect(table.find(order, "Reveal")).toBe(nil)
	end)
end)
