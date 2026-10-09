local Harness = require("./harness")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local HudModel = Harness.requireModule("StarterPlayer.StarterPlayerScripts.Client.HudModel")
local Config = Harness.requireModule("ReplicatedStorage.Shared.Config")

local NOW = 1000

-- A model in the middle of round 3, Run state, 4 players left, target Blue.
local function midRound()
	local model = HudModel.new()
	HudModel.applyState(model, { state = "RoundIntro", endsAt = NOW + 3 })
	HudModel.applyRoundInfo(model, { round = 3, timerSeconds = 8, playersLeft = 4 })
	HudModel.applyTarget(model, { colorId = 2, name = "Blue" })
	HudModel.applyState(model, { state = "Run", endsAt = NOW + 8 })
	return model
end

describe("HudModel.lines", function()
	it("shows placeholders before the server has sent anything", function()
		local lines = HudModel.lines(HudModel.new(), NOW)
		expect(lines.state).toBe("-")
		expect(lines.round).toBe("Round: -")
		expect(lines.target).toBe("Target: -")
		expect(lines.timer).toBe("Time: -")
		expect(lines.playersLeft).toBe("Players left: -")
	end)

	it("shows waiting in the Lobby, with no timer", function()
		local model = HudModel.new()
		HudModel.applyState(model, { state = "Lobby" })
		local lines = HudModel.lines(model, NOW)
		expect(lines.state).toBe("Waiting for players")
		expect(lines.timer).toBe("Time: -")
	end)

	it("counts the Intermission down from the server's endsAt", function()
		local model = HudModel.new()
		HudModel.applyState(model, { state = "Intermission", endsAt = NOW + 10 })
		expect(HudModel.lines(model, NOW).timer).toBe("Time: 10")
		expect(HudModel.lines(model, NOW + 4).timer).toBe("Time: 6.0")
	end)

	it("shows the round, target and players left during a round", function()
		local lines = HudModel.lines(midRound(), NOW + 1)
		expect(lines.state).toBe("Run!")
		expect(lines.round).toBe("Round: 3")
		expect(lines.target).toBe("Target: Blue")
		expect(lines.timer).toBe("Time: 7.0")
		expect(lines.playersLeft).toBe("Players left: 4")
	end)

	it("has text for every match state", function()
		for _, state in
			{
				"Lobby",
				"Intermission",
				"RoundIntro",
				"Run",
				"Elimination",
				"RoundEnd",
				"Victory",
				"Reset",
			}
		do
			local model = HudModel.new()
			HudModel.applyState(model, { state = state })
			local text = HudModel.lines(model, NOW).state
			expect(text ~= "-" and text ~= nil).toBe(true)
		end
	end)
end)

describe("HudModel updates", function()
	it("an elimination updates players left and keeps the round", function()
		local model = midRound()
		HudModel.applyEliminated(model, { userId = 1, playersLeft = 3 })
		local lines = HudModel.lines(model, NOW)
		expect(lines.playersLeft).toBe("Players left: 3")
		expect(lines.round).toBe("Round: 3")
	end)

	it("a repeated RoundInfo after a player leaves updates players left", function()
		local model = midRound()
		HudModel.applyRoundInfo(model, { round = 3, timerSeconds = 8, playersLeft = 2 })
		expect(HudModel.lines(model, NOW).playersLeft).toBe("Players left: 2")
	end)

	it("a later round replaces the target", function()
		local model = midRound()
		HudModel.applyState(model, { state = "RoundIntro", endsAt = NOW + 3 })
		HudModel.applyRoundInfo(model, { round = 4, timerSeconds = 7, playersLeft = 4 })
		HudModel.applyTarget(model, { colorId = 5, name = "Purple" })
		local lines = HudModel.lines(model, NOW)
		expect(lines.round).toBe("Round: 4")
		expect(lines.target).toBe("Target: Purple")
	end)

	it("Elimination, RoundEnd and Victory keep the round details", function()
		for _, state in { "Elimination", "RoundEnd", "Victory" } do
			local model = midRound()
			HudModel.applyState(model, { state = state, endsAt = NOW + 2 })
			local lines = HudModel.lines(model, NOW)
			expect(lines.round).toBe("Round: 3")
			expect(lines.target).toBe("Target: Blue")
			expect(lines.playersLeft).toBe("Players left: 4")
		end
	end)

	it("Reset, Lobby and Intermission clear the round details", function()
		for _, state in { "Reset", "Lobby", "Intermission" } do
			local model = midRound()
			HudModel.applyState(model, { state = state, endsAt = NOW + 2 })
			local lines = HudModel.lines(model, NOW)
			expect(lines.round).toBe("Round: -")
			expect(lines.target).toBe("Target: -")
			expect(lines.playersLeft).toBe("Players left: -")
		end
	end)

	it("a mid-match joiner gets the full picture from the join snapshot", function()
		-- MatchService sends StateChanged, then RoundInfo and TargetAnnounced, on join.
		local model = HudModel.new()
		HudModel.applyState(model, { state = "Run", endsAt = NOW + 5 })
		HudModel.applyRoundInfo(model, { round = 2, timerSeconds = 9, playersLeft = 5 })
		HudModel.applyTarget(model, { colorId = 1, name = "Red" })
		local lines = HudModel.lines(model, NOW)
		expect(lines.state).toBe("Run!")
		expect(lines.round).toBe("Round: 2")
		expect(lines.target).toBe("Target: Red")
		expect(lines.timer).toBe("Time: 5.0")
		expect(lines.playersLeft).toBe("Players left: 5")
	end)
end)

describe("HudModel.formatSeconds", function()
	local threshold = Config.Hud.decimalBelowSeconds

	it("shows whole seconds, rounded up, at or above the threshold", function()
		expect(HudModel.formatSeconds(threshold)).toBe(tostring(threshold))
		expect(HudModel.formatSeconds(threshold + 0.2)).toBe(tostring(threshold + 1))
	end)

	it("shows tenths, rounded down, below the threshold", function()
		expect(HudModel.formatSeconds(threshold - 0.01)).toBe(
			string.format("%.1f", threshold - 0.1)
		)
		expect(HudModel.formatSeconds(2.55)).toBe("2.5")
	end)

	it("never goes below zero once the time is up", function()
		expect(HudModel.formatSeconds(0)).toBe("0.0")
		expect(HudModel.formatSeconds(-3)).toBe("0.0")
	end)
end)

describe("HudModel winners", function()
	local function victory(names: { string })
		local model = midRound()
		HudModel.applyState(model, { state = "Victory", endsAt = NOW + 5 })
		HudModel.applyMatchResult(model, { winnerUserIds = {}, winnerNames = names })
		return model
	end

	it("names a single winner on the state line", function()
		expect(HudModel.lines(victory({ "Alex" }), NOW).state).toBe("Winner: Alex")
	end)

	it("joins two winners with and", function()
		expect(HudModel.lines(victory({ "Alex", "Sam" }), NOW).state).toBe("Winners: Alex and Sam")
	end)

	it("lists every winner when there are exactly as many as the limit", function()
		local limit = Config.Hud.maxWinnerNames
		local names = {}
		for i = 1, limit do
			table.insert(names, "P" .. i)
		end
		-- With a limit of 3: "Winners: P1, P2 and P3".
		local expected = "Winners: " .. table.concat(names, ", ", 1, limit - 1) .. " and P" .. limit
		expect(HudModel.formatWinners(names)).toBe(expected)
	end)

	it("counts the rest once there are more winners than the limit", function()
		local limit = Config.Hud.maxWinnerNames
		local names = {}
		for i = 1, limit + 2 do
			table.insert(names, "P" .. i)
		end
		local shown = {}
		for i = 1, limit do
			table.insert(shown, "P" .. i)
		end
		expect(HudModel.formatWinners(names)).toBe(
			"Winners: " .. table.concat(shown, ", ") .. " and 2 more"
		)
	end)

	it("falls back to Victory when the list is empty", function()
		expect(HudModel.lines(victory({}), NOW).state).toBe("Victory")
	end)

	it("shows Victory until the result arrives", function()
		local model = midRound()
		HudModel.applyState(model, { state = "Victory", endsAt = NOW + 5 })
		expect(HudModel.lines(model, NOW).state).toBe("Victory")
	end)

	it("names the winners when the result arrives before the Victory state", function()
		local model = midRound()
		HudModel.applyState(model, { state = "RoundEnd", endsAt = NOW + 2 })
		HudModel.applyMatchResult(model, { winnerUserIds = { 1 }, winnerNames = { "Alex" } })
		expect(HudModel.lines(model, NOW).state).toBe("Round over")
		HudModel.applyState(model, { state = "Victory", endsAt = NOW + 5 })
		expect(HudModel.lines(model, NOW).state).toBe("Winner: Alex")
	end)

	it("clears the winners when Reset starts", function()
		local model = victory({ "Alex" })
		HudModel.applyState(model, { state = "Reset", endsAt = NOW + 2 })
		expect(HudModel.lines(model, NOW).state).toBe("Resetting")
		HudModel.applyState(model, { state = "Victory", endsAt = NOW + 5 })
		expect(HudModel.lines(model, NOW).state).toBe("Victory")
	end)

	it("keeps its own copy of the names", function()
		local names = { "Alex" }
		local model = victory(names)
		names[1] = "Changed"
		expect(HudModel.lines(model, NOW).state).toBe("Winner: Alex")
	end)
end)
