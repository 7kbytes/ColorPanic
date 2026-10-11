-- H-05 soak test, the half that can run outside Studio.
--
-- The question this answers is narrow but worth locking down: driven for match after match,
-- does the state machine always come back to Lobby, or can it get stuck or spin forever?
-- Every match here is run to completion through MatchFlow with a transition cap, so a state
-- that loops shows up as a failure rather than a hung test.
--
-- What it cannot answer: leaked Instances and client memory growth, which need a real
-- server. Those are the Studio rows of H-05 in qa/sliceH-qa.md.

local Harness = require("./harness")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local MatchFlow = Harness.requireModule("ServerScriptService.Server.MatchFlow")
local ResetAudit = Harness.requireModule("ServerScriptService.Server.ResetAudit")

local MIN_PLAYERS = 2
local MAX_ROUNDS = 8 -- the demo preset's round cap
-- A full match is a few dozen transitions. Anything near this many means it is spinning.
local TRANSITION_CAP = 500

type Eliminator = (round: number, survivors: number) -> number

-- Runs one match from Lobby and returns the states it passed through, in order.
--
-- `eliminate` says how many survivors are lost in a given round. It is clamped so a round
-- never takes everyone out: in the game, if every survivor falls the round replays with the
-- same players, and at the round cap they share the win.
local function runMatch(playerCount: number, eliminate: Eliminator): { string }
	local state = "Lobby"
	local survivors = playerCount
	local round = 0
	local visited = { state }

	for _ = 1, TRANSITION_CAP do
		local sharedWin = false
		if state == "Elimination" then
			local lost = math.clamp(eliminate(round, survivors), 0, math.max(survivors - 1, 0))
			survivors -= lost
			-- Nobody eliminated in the capped round means everyone still standing shares it.
			sharedWin = lost == 0 and round >= MAX_ROUNDS
		end

		local nextState = MatchFlow.nextState(state, {
			playerCount = playerCount,
			survivorCount = survivors,
			minPlayers = MIN_PLAYERS,
			sharedWin = sharedWin,
			round = round,
			maxRounds = MAX_ROUNDS,
		})

		if nextState == "RoundIntro" then
			round += 1
		end

		state = nextState
		table.insert(visited, state)

		-- A match is over once Reset has handed back to Lobby.
		if state == "Lobby" and #visited > 1 then
			return visited
		end
	end

	error(
		string.format(
			"match did not finish within %d transitions, last state %s at round %d",
			TRANSITION_CAP,
			state,
			round
		)
	)
end

local function contains(list: { string }, value: string): boolean
	return table.find(list, value) ~= nil
end

describe("Soak: one match at a time", function()
	it("finishes and returns to the lobby", function()
		local visited = runMatch(4, function()
			return 1
		end)
		expect(contains(visited, "Victory")).toBe(true)
		expect(contains(visited, "Reset")).toBe(true)
		expect(visited[#visited]).toBe("Lobby")
	end)

	it("finishes when nobody is ever eliminated, instead of running forever", function()
		-- Without the round cap this is the match that never ends.
		local visited = runMatch(4, function()
			return 0
		end)
		expect(contains(visited, "Victory")).toBe(true)
		expect(visited[#visited]).toBe("Lobby")
	end)

	it("finishes when everyone is eliminated as fast as the rules allow", function()
		local visited = runMatch(8, function(_, survivors)
			return survivors
		end)
		expect(visited[#visited]).toBe("Lobby")
	end)

	it("finishes when every participant leaves mid-match", function()
		-- playerCount drops below the minimum and survivors hit zero, so it goes to Reset.
		local state = "Run"
		local visited = {}
		for _ = 1, TRANSITION_CAP do
			state = MatchFlow.nextState(state, {
				playerCount = 0,
				survivorCount = 0,
				minPlayers = MIN_PLAYERS,
				round = 3,
				maxRounds = MAX_ROUNDS,
			})
			table.insert(visited, state)
			if state == "Lobby" then
				break
			end
		end
		expect(contains(visited, "Reset")).toBe(true)
		expect(visited[#visited]).toBe("Lobby")
	end)

	it("stays in the lobby below the minimum player count", function()
		expect(MatchFlow.nextState("Lobby", {
			playerCount = 1,
			survivorCount = 0,
			minPlayers = MIN_PLAYERS,
		})).toBe("Lobby")
	end)
end)

describe("Soak: matches back to back", function()
	-- H-05 asks for five or more in a row. Ten, with the player count changing between
	-- them, since in a real server people join and leave between matches.
	local MATCHES = 10

	it("runs ten matches in a row, each ending in the lobby", function()
		for index = 1, MATCHES do
			local players = 2 + (index % 7) -- 2 to 8 players, varying each match
			local visited = runMatch(players, function(round)
				return if round % 3 == 0 then 0 else 1 -- some rounds nobody falls
			end)
			expect(visited[#visited]).toBe("Lobby")
			expect(contains(visited, "Victory")).toBe(true)
		end
	end)

	it("takes a similar number of transitions every time, so nothing accumulates", function()
		local lengths = {}
		for _ = 1, MATCHES do
			local visited = runMatch(4, function()
				return 1
			end)
			table.insert(lengths, #visited)
		end
		-- Identical input should give an identical match every time. A match that grew as
		-- the server stayed up would be the state machine holding onto something.
		for _, length in lengths do
			expect(length).toBe(lengths[1])
		end
	end)

	it("never needs anything like the transition cap", function()
		local visited = runMatch(8, function()
			return 1
		end)
		-- Guards the cap itself: if a real match ever came close, the cap would stop
		-- catching stuck states and start causing false failures.
		expect(#visited < TRANSITION_CAP // 4).toBe(true)
	end)
end)

describe("Soak: the reset audit over many matches", function()
	local function snapshot(parts: number, baseline: number)
		return {
			tileCount = 0,
			survivorCount = 0,
			spectatorCount = 0,
			partCount = parts,
			baselinePartCount = baseline,
			outsideLobby = {},
		}
	end

	it("is clean every time when each match cleans up after itself", function()
		local baseline = 120
		for _ = 1, 10 do
			expect(#ResetAudit.findProblems(snapshot(baseline, baseline))).toBe(0)
		end
	end)

	it("catches a leak that only shows up after several matches", function()
		-- Two parts left behind per match is invisible in one match and obvious in ten.
		-- This is the failure the Studio rows of H-05 are looking for.
		local baseline = 120
		local parts = baseline
		local firstFlagged = nil
		for match = 1, 10 do
			parts += 2
			local problems = ResetAudit.findProblems(snapshot(parts, baseline))
			if #problems > 0 and firstFlagged == nil then
				firstFlagged = match
			end
		end
		expect(firstFlagged).toBe(1) -- flagged immediately, not after it has piled up
	end)

	it("catches survivors or spectators still tracked after a reset", function()
		local stuck = snapshot(120, 120)
		stuck.survivorCount = 1
		expect(#ResetAudit.findProblems(stuck)).toBe(1)

		local spectating = snapshot(120, 120)
		spectating.spectatorCount = 2
		expect(#ResetAudit.findProblems(spectating)).toBe(1)
	end)

	it("catches a player left outside the lobby", function()
		local outside = snapshot(120, 120)
		outside.outsideLobby = { "luxygee" }
		expect(#ResetAudit.findProblems(outside)).toBe(1)
	end)
end)
