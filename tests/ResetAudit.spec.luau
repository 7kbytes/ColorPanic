local Harness = require("./harness")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local ResetAudit = Harness.requireModule("ServerScriptService.Server.ResetAudit")

local function clean()
	return {
		tileCount = 0,
		survivorCount = 0,
		spectatorCount = 0,
		partCount = 40,
		baselinePartCount = 40,
		outsideLobby = {},
	}
end

describe("ResetAudit.findProblems", function()
	it("finds nothing after a clean reset", function()
		expect(#ResetAudit.findProblems(clean())).toBe(0)
	end)

	it("reports leftover tiles", function()
		local snapshot = clean()
		snapshot.tileCount = 3
		local problems = ResetAudit.findProblems(snapshot)
		expect(#problems).toBe(1)
		expect(problems[1]).toBe("3 arena tiles left")
	end)

	it("reports players still tracked by the match", function()
		local snapshot = clean()
		snapshot.survivorCount = 1
		snapshot.spectatorCount = 2
		local problems = ResetAudit.findProblems(snapshot)
		expect(#problems).toBe(2)
		expect(problems[1]).toBe("1 survivors still tracked")
		expect(problems[2]).toBe("2 spectators still tracked")
	end)

	it("reports a part count that differs from the baseline either way", function()
		local more = clean()
		more.partCount = 41
		expect(ResetAudit.findProblems(more)[1]).toBe("workspace has 41 parts, expected 40")
		local fewer = clean()
		fewer.partCount = 39
		expect(#ResetAudit.findProblems(fewer)).toBe(1)
	end)

	it("names players who are not back in the lobby", function()
		local snapshot = clean()
		snapshot.outsideLobby = { "Player1", "Player2" }
		expect(ResetAudit.findProblems(snapshot)[1]).toBe("not in the lobby: Player1, Player2")
	end)

	it("reports every problem at once", function()
		local snapshot = clean()
		snapshot.tileCount = 1
		snapshot.survivorCount = 1
		snapshot.spectatorCount = 1
		snapshot.partCount = 50
		snapshot.outsideLobby = { "Player1" }
		expect(#ResetAudit.findProblems(snapshot)).toBe(5)
	end)
end)
