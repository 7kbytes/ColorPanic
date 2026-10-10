local Harness = require("./harness")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local HudModel = Harness.requireModule("StarterPlayer.StarterPlayerScripts.Client.HudModel")
local Config = Harness.requireModule("ReplicatedStorage.Shared.Config")

local NOW = 1000
local HIDDEN = Config.Hud.hiddenText

-- The view as flat fields, so the tests below read like the HUD: nil means the piece is hidden.
local function flat(model, now: number)
	local view = HudModel.view(model, now)
	return {
		state = view.status,
		round = view.roundText,
		target = if view.target then view.target.name else nil,
		timer = if view.timer then view.timer.text else nil,
		playersLeft = view.playersLeft,
	}
end

local function roundText(round: number): string
	return HudModel.formatRound(round, Config.Match.maxRounds)
end

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

describe("HudModel.view", function()
	it("hides every piece before the server has sent anything", function()
		local lines = flat(HudModel.new(), NOW)
		expect(lines.state).toBe("-")
		expect(lines.round).toBe(nil)
		expect(lines.target).toBe(nil)
		expect(lines.timer).toBe(nil)
		expect(lines.playersLeft).toBe(nil)
	end)

	it("shows waiting in the Lobby, with no timer", function()
		local model = HudModel.new()
		HudModel.applyState(model, { state = "Lobby" })
		local lines = flat(model, NOW)
		expect(lines.state).toBe("Waiting for players")
		expect(lines.timer).toBe(nil)
	end)

	it("counts the Intermission down from the server's endsAt", function()
		local model = HudModel.new()
		HudModel.applyState(model, { state = "Intermission", endsAt = NOW + 10 })
		expect(flat(model, NOW).timer).toBe("10")
		expect(flat(model, NOW + 4).timer).toBe("6.0")
	end)

	it("shows the round, target and players left during a round", function()
		local lines = flat(midRound(), NOW + 1)
		expect(lines.state).toBe("Run!")
		expect(lines.round).toBe(roundText(3))
		expect(lines.target).toBe(Config.Colors[2].name)
		expect(lines.timer).toBe("7.0")
		expect(lines.playersLeft).toBe("4")
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
			local text = flat(model, NOW).state
			expect(text ~= "-" and text ~= nil).toBe(true)
		end
	end)
end)

describe("HudModel updates", function()
	it("an elimination updates players left and keeps the round", function()
		local model = midRound()
		HudModel.applyEliminated(model, { userId = 1, playersLeft = 3 })
		local lines = flat(model, NOW)
		expect(lines.playersLeft).toBe("3")
		expect(lines.round).toBe(roundText(3))
	end)

	it("a repeated RoundInfo after a player leaves updates players left", function()
		local model = midRound()
		HudModel.applyRoundInfo(model, { seq = 1, round = 3, timerSeconds = 8, playersLeft = 2 })
		expect(flat(model, NOW).playersLeft).toBe("2")
	end)

	it("a later round replaces the target", function()
		local model = midRound()
		HudModel.applyState(model, { state = "RoundIntro", endsAt = NOW + 3 })
		HudModel.applyRoundInfo(model, { seq = 2, round = 4, timerSeconds = 7, playersLeft = 4 })
		HudModel.applyTarget(model, targetPayload(5, 2), NOW)
		local lines = flat(model, NOW)
		expect(lines.round).toBe(roundText(4))
		expect(lines.target).toBe(Config.Colors[5].name)
	end)

	it("Elimination, RoundEnd and Victory keep the round details", function()
		for _, state in { "Elimination", "RoundEnd", "Victory" } do
			local model = midRound()
			HudModel.applyState(model, { state = state, endsAt = NOW + 2 })
			local lines = flat(model, NOW)
			expect(lines.round).toBe(roundText(3))
			expect(lines.target).toBe(Config.Colors[2].name)
			expect(lines.playersLeft).toBe("4")
		end
	end)

	it("Reset, Lobby and Intermission clear the round details", function()
		for _, state in { "Reset", "Lobby", "Intermission" } do
			local model = midRound()
			HudModel.applyState(model, { state = state, endsAt = NOW + 2 })
			local lines = flat(model, NOW)
			expect(lines.round).toBe(nil)
			expect(lines.target).toBe(nil)
			expect(lines.playersLeft).toBe(nil)
		end
	end)

	it("a mid-match joiner gets the full picture from the join snapshot", function()
		-- MatchService now sends RoundInfo and TargetAnnounced before StateChanged on join (see
		-- Broadcast); this checks the HUD also copes with the state arriving first.
		local model = HudModel.new()
		HudModel.applyState(model, { state = "Run", endsAt = NOW + 5 })
		HudModel.applyRoundInfo(model, { seq = 1, round = 2, timerSeconds = 9, playersLeft = 5 })
		HudModel.applyTarget(model, targetPayload(1), NOW)
		local lines = flat(model, NOW)
		expect(lines.state).toBe("Run!")
		expect(lines.round).toBe(roundText(2))
		expect(lines.target).toBe(Config.Colors[1].name)
		expect(lines.timer).toBe("5.0")
		expect(lines.playersLeft).toBe("5")
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
		expect(flat(victory({ "Alex" }), NOW).state).toBe("Winner: Alex")
	end)

	it("joins two winners with and", function()
		expect(flat(victory({ "Alex", "Sam" }), NOW).state).toBe("Winners: Alex and Sam")
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
		expect(flat(victory({}), NOW).state).toBe("Victory")
	end)

	it("shows Victory until the result arrives", function()
		local model = midRound()
		HudModel.applyState(model, { state = "Victory", endsAt = NOW + 5 })
		expect(flat(model, NOW).state).toBe("Victory")
	end)

	it("names the winners when the result arrives before the Victory state", function()
		local model = midRound()
		HudModel.applyState(model, { state = "RoundEnd", endsAt = NOW + 2 })
		HudModel.applyMatchResult(model, { winnerUserIds = { 1 }, winnerNames = { "Alex" } })
		expect(flat(model, NOW).state).toBe("Round over")
		HudModel.applyState(model, { state = "Victory", endsAt = NOW + 5 })
		expect(flat(model, NOW).state).toBe("Winner: Alex")
	end)

	it("clears the winners when Reset starts", function()
		local model = victory({ "Alex" })
		HudModel.applyState(model, { state = "Reset", endsAt = NOW + 2 })
		expect(flat(model, NOW).state).toBe("Resetting")
		HudModel.applyState(model, { state = "Victory", endsAt = NOW + 5 })
		expect(flat(model, NOW).state).toBe("Victory")
	end)

	it("keeps its own copy of the names", function()
		local names = { "Alex" }
		local model = victory(names)
		names[1] = "Changed"
		expect(flat(model, NOW).state).toBe("Winner: Alex")
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
		expect(flat(model, NOW - 1).target).toBe(HIDDEN)
		expect(HudModel.targetView(model, NOW - 1).hidden).toBe(true)
	end)

	it("shows the target for the reveal window at the start of Run", function()
		local model = revealRound()
		startRun(model, 3)
		expect(flat(model, NOW).target).toBe(Config.Colors[3].name)
		expect(flat(model, NOW + 1.9).target).toBe(Config.Colors[3].name)
		expect(HudModel.targetView(model, NOW + 1).colorId).toBe(3)
	end)

	it("hides the target from revealUntil until Run ends", function()
		local model = revealRound()
		startRun(model, 3)
		expect(flat(model, NOW + 2).target).toBe(HIDDEN)
		expect(flat(model, NOW + 9).target).toBe(HIDDEN)
		expect(HudModel.targetView(model, NOW + 5).colorId).toBe(nil)
	end)

	it("shows the target again once the tiles drop", function()
		local model = revealRound()
		startRun(model, 3)
		HudModel.applyState(model, { state = "Elimination", endsAt = NOW + 13 })
		expect(flat(model, NOW + 11).target).toBe(Config.Colors[3].name)
	end)

	it("a player who joins after the reveal sees it hidden", function()
		-- Join snapshot with the state first and a target whose revealUntil is in the past.
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
		expect(flat(model, NOW).target).toBe(HIDDEN)
	end)

	it("never shows the previous round's target in a new reveal round", function()
		local model = midRound() -- seq 1, target color 2, visible
		HudModel.applyState(model, { state = "RoundIntro", endsAt = NOW + 4 })
		HudModel.applyRoundInfo(
			model,
			{ seq = 2, round = 4, timerSeconds = 9, playersLeft = 4, revealSeconds = 2 }
		)
		expect(flat(model, NOW).target).toBe(HIDDEN)
	end)

	it("ignores an old target that arrives after the new round's info", function()
		local model = revealRound() -- seq 4
		HudModel.applyTarget(model, targetPayload(1, 3), NOW) -- seq 3, a late duplicate
		expect(flat(model, NOW).target).toBe(HIDDEN)
	end)

	it("in a normal round, a target that arrives before RoundInfo shows once it does", function()
		local model = midRound() -- seq 1
		HudModel.applyState(model, { state = "RoundIntro", endsAt = NOW + 4 })
		HudModel.applyTarget(model, targetPayload(6, 2), NOW)
		expect(flat(model, NOW).target).toBe(nil)
		HudModel.applyRoundInfo(model, { seq = 2, round = 4, timerSeconds = 9, playersLeft = 4 })
		expect(flat(model, NOW).target).toBe(Config.Colors[6].name)
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
		expect(flat(model, NOW + 2.1).target).toBe(Config.Colors[4].name)
		expect(flat(model, NOW + 2.3).target).toBe(HIDDEN)
	end)
end)

describe("HudModel badges and target card (D-06)", function()
	it("shows the round cap when the match has one", function()
		expect(HudModel.formatRound(3, 8)).toBe("Round 3/8")
		expect(HudModel.formatRound(3, math.huge)).toBe("Round 3")
	end)

	it("hides the round badge while a state is known but its round is not (#17)", function()
		local model = HudModel.new()
		HudModel.applyState(model, { state = "RoundIntro", endsAt = NOW + 4, duration = 4 })
		local view = HudModel.view(model, NOW)
		expect(view.roundText).toBe(nil)
		expect(view.playersLeft).toBe(nil)
		expect(view.target).toBe(nil)
		HudModel.applyRoundInfo(model, { seq = 1, round = 1, timerSeconds = 14, playersLeft = 2 })
		expect(HudModel.view(model, NOW).roundText).toBe(roundText(1))
	end)

	it("RoundInfo sent before the state keeps the round when the state arrives", function()
		local model = HudModel.new()
		HudModel.applyState(model, { state = "Intermission", endsAt = NOW, duration = 5 })
		HudModel.applyRoundInfo(model, { seq = 1, round = 1, timerSeconds = 14, playersLeft = 2 })
		HudModel.applyTarget(model, targetPayload(4, 1), NOW)
		HudModel.applyState(model, { state = "RoundIntro", endsAt = NOW + 4, duration = 4 })
		local view = HudModel.view(model, NOW)
		expect(view.roundText).toBe(roundText(1))
		expect((view.target :: any).name).toBe(Config.Colors[4].name)
	end)

	it("the target card carries the palette color and shape from Config", function()
		for _, colorDef in Config.Colors do
			local model = midRound()
			HudModel.applyTarget(model, targetPayload(colorDef.id), NOW)
			local card = HudModel.view(model, NOW).target :: any
			expect(card.hidden).toBe(false)
			expect(card.colorId).toBe(colorDef.id)
			expect(card.shape).toBe(colorDef.shape)
			expect(card.hex).toBe(colorDef.hex)
		end
	end)

	it("a hidden target shows neither color nor shape", function()
		local model = HudModel.new()
		HudModel.applyState(model, { state = "RoundIntro", endsAt = NOW + 4 })
		HudModel.applyRoundInfo(
			model,
			{ seq = 2, round = 3, timerSeconds = 12, playersLeft = 2, revealSeconds = 2 }
		)
		local card = HudModel.view(model, NOW).target :: any
		expect(card.hidden).toBe(true)
		expect(card.name).toBe(HIDDEN)
		expect(card.colorId).toBe(nil)
		expect(card.shape).toBe(nil)
		expect(card.hex).toBe(nil)
	end)
end)

describe("HudModel timer bar (D-06)", function()
	local function running(duration: number)
		local model = midRound()
		HudModel.applyState(model, { state = "Run", endsAt = NOW + duration, duration = duration })
		return model
	end

	it("shrinks from full to empty across the state", function()
		local model = running(10)
		expect((HudModel.view(model, NOW).timer :: any).fraction).toBeCloseTo(1)
		expect((HudModel.view(model, NOW + 5).timer :: any).fraction).toBeCloseTo(0.5)
		expect((HudModel.view(model, NOW + 12).timer :: any).fraction).toBeCloseTo(0)
	end)

	it("a late joiner sees the bar part-way down", function()
		local model = HudModel.new()
		-- Joined 6 s into a 10 s Run.
		HudModel.applyState(model, { state = "Run", endsAt = NOW + 4, duration = 10 })
		expect((HudModel.view(model, NOW).timer :: any).fraction).toBeCloseTo(0.4)
	end)

	it("stays full when the server sent no duration", function()
		local model = HudModel.new()
		HudModel.applyState(model, { state = "Run", endsAt = NOW + 4 })
		expect((HudModel.view(model, NOW).timer :: any).fraction).toBe(1)
	end)

	it("warns only in the last warningSeconds of Run", function()
		local warn = Config.Hud.warningSeconds
		local model = running(10)
		expect((HudModel.view(model, NOW + 10 - warn - 0.1).timer :: any).warning).toBe(false)
		expect((HudModel.view(model, NOW + 10 - warn).timer :: any).warning).toBe(true)
		expect((HudModel.view(model, NOW + 10).timer :: any).warning).toBe(true)
	end)

	it("never warns outside Run", function()
		local model = HudModel.new()
		HudModel.applyState(model, { state = "Intermission", endsAt = NOW + 1, duration = 5 })
		local timer = HudModel.view(model, NOW).timer :: any
		expect(timer.text).toBe("1.0")
		expect(timer.warning).toBe(false)
	end)

	it("shows only in the timer states", function()
		for _, state in { "Lobby", "RoundIntro", "Elimination", "RoundEnd", "Victory", "Reset" } do
			local model = HudModel.new()
			HudModel.applyState(model, { state = state, endsAt = NOW + 3, duration = 3 })
			local shown = table.find(Config.Hud.timerStates, state) ~= nil
			expect(HudModel.view(model, NOW).timer ~= nil).toBe(shown)
		end
	end)
end)
