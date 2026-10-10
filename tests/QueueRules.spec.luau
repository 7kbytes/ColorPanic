local Harness = require("./harness")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local QueueRules = Harness.requireModule("ServerScriptService.Server.QueueRules")

local ROLES = { "Menu", "Lobby", "Survivor", "Spectator" }
local STATES =
	{ "Lobby", "Intermission", "RoundIntro", "Run", "Elimination", "RoundEnd", "Victory", "Reset" }

describe("QueueRules.canPlay", function()
	it("accepts Play only from the menu", function()
		for _, role in ROLES do
			expect(QueueRules.canPlay(role)).toBe(role == "Menu")
		end
	end)
end)

describe("QueueRules.canLeave", function()
	it("accepts Leave from the lobby before a match starts", function()
		expect(QueueRules.canLeave("Lobby", "Lobby")).toBe(true)
		expect(QueueRules.canLeave("Lobby", "Intermission")).toBe(true)
	end)

	it("refuses Leave during a match, whatever the role", function()
		for _, state in STATES do
			if state ~= "Lobby" and state ~= "Intermission" then
				for _, role in ROLES do
					expect(QueueRules.canLeave(role, state)).toBe(false)
				end
			end
		end
	end)

	it("refuses Leave from the menu, the arena and the spectator area", function()
		for _, role in { "Menu", "Survivor", "Spectator" } do
			expect(QueueRules.canLeave(role, "Lobby")).toBe(false)
			expect(QueueRules.canLeave(role, "Intermission")).toBe(false)
		end
	end)
end)

describe("QueueRules.isOffCooldown", function()
	it("allows the first request", function()
		expect(QueueRules.isOffCooldown(nil, 10, 1)).toBe(true)
	end)

	it("refuses a request inside the cooldown and allows one after it", function()
		expect(QueueRules.isOffCooldown(10, 10.5, 1)).toBe(false)
		expect(QueueRules.isOffCooldown(10, 11, 1)).toBe(true)
	end)
end)

describe("QueueRules.roleAfterPlay", function()
	it("waits in the lobby between matches and as a spectator during one", function()
		expect(QueueRules.roleAfterPlay(false)).toBe("Lobby")
		expect(QueueRules.roleAfterPlay(true)).toBe("Spectator")
	end)
end)
