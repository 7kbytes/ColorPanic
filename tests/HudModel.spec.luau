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
