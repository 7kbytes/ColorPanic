local Harness = require("./harness")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local HudModel = Harness.requireModule("StarterPlayer.StarterPlayerScripts.Client.HudModel")
local Config = Harness.requireModule("ReplicatedStorage.Shared.Config")

local NOW = 1000

-- Payloads use the real palette from Config, as the server sends them.
local function targetPayload(id: number, seq: number?)
	return { seq = seq or 1, colorId = id, name = Config.Colors[id].name }
end

-- A model in the middle of round 3, Run state, 4 players left, target color 2.
local function midRound()
	local model = HudModel.new()
	HudModel.applyState(model, { state = "RoundIntro", endsAt = NOW + 3 })
	HudModel.applyRoundInfo(model, { seq = 1, round = 3, timerSeconds = 8, playersLeft = 4 })
	HudModel.applyTarget(model, targetPayload(2), NOW)
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
		expect(lines.target).toBe("Target: " .. Config.Colors[2].name)
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
		HudModel.applyRoundInfo(model, { seq = 1, round = 3, timerSeconds = 8, playersLeft = 2 })
		expect(HudModel.lines(model, NOW).playersLeft).toBe("Players left: 2")
	end)

	it("a later round replaces the target", function()
		local model = midRound()
		HudModel.applyState(model, { state = "RoundIntro", endsAt = NOW + 3 })
		HudModel.applyRoundInfo(model, { seq = 2, round = 4, timerSeconds = 7, playersLeft = 4 })
		HudModel.applyTarget(model, targetPayload(5, 2), NOW)
		local lines = HudModel.lines(model, NOW)
		expect(lines.round).toBe("Round: 4")
		expect(lines.target).toBe("Target: " .. Config.Colors[5].name)
	end)

	it("Elimination, RoundEnd and Victory keep the round details", function()
		for _, state in { "Elimination", "RoundEnd", "Victory" } do
			local model = midRound()
			HudModel.applyState(model, { state = state, endsAt = NOW + 2 })
			local lines = HudModel.lines(model, NOW)
			expect(lines.round).toBe("Round: 3")
			expect(lines.target).toBe("Target: " .. Config.Colors[2].name)
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
		HudModel.applyRoundInfo(model, { seq = 1, round = 2, timerSeconds = 9, playersLeft = 5 })
		HudModel.applyTarget(model, targetPayload(1), NOW)
		local lines = HudModel.lines(model, NOW)
		expect(lines.state).toBe("Run!")
		expect(lines.round).toBe("Round: 2")
		expect(lines.target).toBe("Target: " .. Config.Colors[1].name)
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

describe("HudModel reveal-then-hide", function()
	-- A reveal round: seq 4, round 5, 2 s reveal. RoundIntro, then Run from NOW.
	local function revealRound()
		local model = HudModel.new()
		HudModel.applyState(model, { state = "RoundIntro", endsAt = NOW })
		HudModel.applyRoundInfo(
			model,
			{ seq = 4, round = 5, timerSeconds = 10, playersLeft = 3, revealSeconds = 2 }
		)
		return model
	end

	local function startRun(model, colorId: number)
		HudModel.applyState(model, { state = "Run", endsAt = NOW + 10 })
		local payload = targetPayload(colorId, 4)
		payload.revealUntil = NOW + 2
		payload.revealSeconds = 2
		HudModel.applyTarget(model, payload, NOW)
	end

	it("hides the target during RoundIntro, before the reveal", function()
		local model = revealRound()
		expect(HudModel.lines(model, NOW - 1).target).toBe("Target: ?")
		expect(HudModel.targetView(model, NOW - 1).hidden).toBe(true)
	end)

	it("shows the target for the reveal window at the start of Run", function()
		local model = revealRound()
		startRun(model, 3)
		expect(HudModel.lines(model, NOW).target).toBe("Target: " .. Config.Colors[3].name)
		expect(HudModel.lines(model, NOW + 1.9).target).toBe("Target: " .. Config.Colors[3].name)
		expect(HudModel.targetView(model, NOW + 1).colorId).toBe(3)
	end)

	it("hides the target from revealUntil until Run ends", function()
		local model = revealRound()
		startRun(model, 3)
		expect(HudModel.lines(model, NOW + 2).target).toBe("Target: ?")
		expect(HudModel.lines(model, NOW + 9).target).toBe("Target: ?")
		expect(HudModel.targetView(model, NOW + 5).colorId).toBe(nil)
	end)

	it("shows the target again once the tiles drop", function()
		local model = revealRound()
		startRun(model, 3)
		HudModel.applyState(model, { state = "Elimination", endsAt = NOW + 13 })
		expect(HudModel.lines(model, NOW + 11).target).toBe("Target: " .. Config.Colors[3].name)
	end)

	it("a player who joins after the reveal sees it hidden", function()
		-- Join snapshot: state, round info, then the target with a revealUntil in the past.
		local model = HudModel.new()
		HudModel.applyState(model, { state = "Run", endsAt = NOW + 6 })
		HudModel.applyRoundInfo(
			model,
			{ seq = 4, round = 5, timerSeconds = 10, playersLeft = 3, revealSeconds = 2 }
		)
		local payload = targetPayload(3, 4)
		payload.revealUntil = NOW - 2
		payload.revealSeconds = 2
		HudModel.applyTarget(model, payload, NOW)
		expect(HudModel.lines(model, NOW).target).toBe("Target: ?")
	end)

	it("never shows the previous round's target in a new reveal round", function()
		local model = midRound() -- seq 1, target color 2, visible
		HudModel.applyState(model, { state = "RoundIntro", endsAt = NOW + 4 })
		HudModel.applyRoundInfo(
			model,
			{ seq = 2, round = 4, timerSeconds = 9, playersLeft = 4, revealSeconds = 2 }
		)
		expect(HudModel.lines(model, NOW).target).toBe("Target: ?")
	end)

	it("ignores an old target that arrives after the new round's info", function()
		local model = revealRound() -- seq 4
		HudModel.applyTarget(model, targetPayload(1, 3), NOW) -- seq 3, a late duplicate
		expect(HudModel.lines(model, NOW).target).toBe("Target: ?")
	end)

	it("in a normal round, a target that arrives before RoundInfo shows once it does", function()
		local model = midRound() -- seq 1
		HudModel.applyState(model, { state = "RoundIntro", endsAt = NOW + 4 })
		HudModel.applyTarget(model, targetPayload(6, 2), NOW)
		expect(HudModel.lines(model, NOW).target).toBe("Target: -")
		HudModel.applyRoundInfo(model, { seq = 2, round = 4, timerSeconds = 9, playersLeft = 4 })
		expect(HudModel.lines(model, NOW).target).toBe("Target: " .. Config.Colors[6].name)
	end)
end)

describe("HudModel reveal arriving late", function()
	it("shows the target for the full reveal from when it arrives", function()
		local model = HudModel.new()
		HudModel.applyState(model, { state = "Run", endsAt = NOW + 10 })
		HudModel.applyRoundInfo(
			model,
			{ seq = 7, round = 3, timerSeconds = 10, playersLeft = 2, revealSeconds = 2 }
		)
		-- The server revealed at NOW (revealUntil NOW + 2); this client gets it 0.3 s later.
		local payload = targetPayload(4, 7)
		payload.revealUntil = NOW + 2
		payload.revealSeconds = 2
		HudModel.applyTarget(model, payload, NOW + 0.3)
		expect(HudModel.lines(model, NOW + 2.1).target).toBe("Target: " .. Config.Colors[4].name)
		expect(HudModel.lines(model, NOW + 2.3).target).toBe("Target: ?")
	end)
end)
