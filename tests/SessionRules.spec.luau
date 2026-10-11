local Harness = require("./harness")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local SessionRules = Harness.requireModule("ReplicatedStorage.Shared.SessionRules")

describe("SessionRules.profileKey", function()
	it("builds the key from the user id", function()
		expect(SessionRules.profileKey(12345)).toBe("player_12345")
	end)

	it("is stable for the same id", function()
		expect(SessionRules.profileKey(7)).toBe(SessionRules.profileKey(7))
	end)

	it("differs between players", function()
		expect(SessionRules.profileKey(1) == SessionRules.profileKey(2)).toBe(false)
	end)
end)

describe("SessionRules.decideStart", function()
	it("plays live when the session started", function()
		local decision = SessionRules.decideStart(true, true, true)
		expect(decision.mode).toBe("live")
		expect(decision.kick).toBe(false)
	end)

	it("kicks when the store works but the lock is held elsewhere", function()
		local decision = SessionRules.decideStart(true, false, true)
		expect(decision.kick).toBe(true)
		expect(decision.mode).toBe("cache")
	end)

	it("plays on without saving when there is no store", function()
		-- Studio without API Services. Kicking here would make the game untestable.
		local decision = SessionRules.decideStart(false, false, true)
		expect(decision.kick).toBe(false)
		expect(decision.mode).toBe("cache")
	end)

	it("never kicks a player who already left", function()
		expect(SessionRules.decideStart(true, false, false).kick).toBe(false)
		expect(SessionRules.decideStart(true, true, false).kick).toBe(false)
		expect(SessionRules.decideStart(false, false, false).kick).toBe(false)
	end)

	it("does not treat a player who left as a live session", function()
		-- Their lock is handed straight back, so nothing should be saved against it.
		expect(SessionRules.decideStart(true, true, false).mode).toBe("cache")
	end)

	it("gives a reason for every outcome", function()
		local cases = {
			SessionRules.decideStart(true, true, true),
			SessionRules.decideStart(true, false, true),
			SessionRules.decideStart(false, false, true),
			SessionRules.decideStart(true, false, false),
		}
		for _, decision in cases do
			expect(type(decision.reason)).toBe("string")
			expect(decision.reason == "").toBe(false)
		end
	end)
end)

describe("SessionRules.canSave", function()
	it("allows writes only for a live session", function()
		expect(SessionRules.canSave("live")).toBe(true)
		expect(SessionRules.canSave("cache")).toBe(false)
	end)

	it("blocks writes for every decision that is not live", function()
		expect(SessionRules.canSave(SessionRules.decideStart(false, false, true).mode)).toBe(false)
		expect(SessionRules.canSave(SessionRules.decideStart(true, false, true).mode)).toBe(false)
		expect(SessionRules.canSave(SessionRules.decideStart(true, true, true).mode)).toBe(true)
	end)
end)

describe("SessionRules.shouldKickOnSessionEnd", function()
	it("kicks a player whose profile was taken over while playing", function()
		expect(SessionRules.shouldKickOnSessionEnd(true, false)).toBe(true)
	end)

	it("does not kick when we ended the session ourselves", function()
		-- The normal path when a player leaves, and on server shutdown.
		expect(SessionRules.shouldKickOnSessionEnd(true, true)).toBe(false)
	end)

	it("does not kick a player who has already gone", function()
		expect(SessionRules.shouldKickOnSessionEnd(false, false)).toBe(false)
		expect(SessionRules.shouldKickOnSessionEnd(false, true)).toBe(false)
	end)
end)
