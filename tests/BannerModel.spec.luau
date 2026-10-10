local Harness = require("./harness")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local BannerModel = Harness.requireModule("StarterPlayer.StarterPlayerScripts.Client.BannerModel")
local HudModel = Harness.requireModule("StarterPlayer.StarterPlayerScripts.Client.HudModel")
local Config = Harness.requireModule("ReplicatedStorage.Shared.Config")
local Util = Harness.requireModule("ReplicatedStorage.Shared.Util")

local NOW = 1000

local function roundInfo(round: number, extra: { [string]: any }?)
	local payload = {
		seq = round,
		round = round,
		timerSeconds = 12,
		playersLeft = 4,
		colorCount = 4,
		replay = false,
	}
	for key, value in extra or {} do
		payload[key] = value
	end
	return payload
end

-- A client in RoundIntro, with RoundInfo sent before the state as the server does.
local function intro(round: number, extra: { [string]: any }?)
	local model = HudModel.new()
	HudModel.applyRoundInfo(model, roundInfo(round, extra))
	HudModel.applyState(model, { state = "RoundIntro", endsAt = NOW + 4, duration = 4 })
	return model
end

describe("BannerModel intermission", function()
	it("counts the match start down from the server's endsAt", function()
		local model = HudModel.new()
		HudModel.applyState(model, { state = "Intermission", endsAt = NOW + 5, duration = 5 })
		local banner = BannerModel.view(model, NOW) :: any
		expect(banner.kind).toBe("Intermission")
		expect(banner.title).toBe("Match starting")
		expect(banner.subtitle).toBe("5")
		expect((BannerModel.view(model, NOW + 3.2) :: any).subtitle).toBe("2")
		expect((BannerModel.view(model, NOW + 9) :: any).subtitle).toBe("0")
	end)
end)

describe("BannerModel round intro", function()
	it("names the round with its colors and timer", function()
		local banner = BannerModel.view(intro(3), NOW) :: any
		expect(banner.kind).toBe("Round")
		expect(banner.title).toBe("Round 3")
		expect(banner.subtitle).toBe("4 colors · 12 seconds")
	end)

	it("shows a fractional timer as it is", function()
		local banner = BannerModel.view(intro(2, { timerSeconds = 6.5 }), NOW) :: any
		expect(banner.subtitle).toBe("4 colors · 6.5 seconds")
	end)

	it("asks players to memorize the color in a reveal round", function()
		local banner = BannerModel.view(intro(3, { revealSeconds = 2 }), NOW) :: any
		expect(banner.subtitle).toBe("Memorize the color!")
	end)

	it("calls out a replay after everyone fell", function()
		local banner = BannerModel.view(intro(3, { replay = true }), NOW) :: any
		expect(banner.kind).toBe("Replay")
		expect(banner.title).toBe("Everyone fell!")
		expect(banner.subtitle).toBe("Round 3 again")
	end)

	it("the next round clears the replay", function()
		local model = intro(3, { replay = true })
		HudModel.applyRoundInfo(model, roundInfo(4))
		expect((BannerModel.view(model, NOW) :: any).kind).toBe("Round")
	end)

	it("announces the last round of a capped match", function()
		local cap = Config.Match.maxRounds
		if cap == math.huge then
			return -- no cap in this preset, so there is no final round
		end
		local banner = BannerModel.view(intro(cap), NOW) :: any
		expect(banner.kind).toBe("Final")
		expect(banner.title).toBe("Final round!")
		expect((BannerModel.view(intro(cap - 1), NOW) :: any).kind).toBe("Round")
	end)

	it("a player who joins during the intro sees the banner", function()
		-- Join snapshot: round info, then the state, part way through RoundIntro.
		local model = HudModel.new()
		HudModel.applyRoundInfo(model, roundInfo(5))
		HudModel.applyState(model, { state = "RoundIntro", endsAt = NOW + 1, duration = 4 })
		expect((BannerModel.view(model, NOW) :: any).title).toBe("Round 5")
	end)

	it("waits for the round info before showing a round banner", function()
		local model = HudModel.new()
		HudModel.applyState(model, { state = "RoundIntro", endsAt = NOW + 4, duration = 4 })
		expect(BannerModel.view(model, NOW)).toBe(nil)
	end)
end)

describe("BannerModel names the target (D-09)", function()
	it("asks players to find the target by color and shape", function()
		local model = intro(3)
		HudModel.applyTarget(model, { seq = 3, colorId = 1, name = Config.Colors[1].name }, NOW)
		local expected =
			string.format("Find the %s · 12 seconds", Util.displayName(Config.Colors[1]))
		expect((BannerModel.view(model, NOW) :: any).subtitle).toBe(expected)
	end)
end)

describe("BannerModel shrinking tiles (D-10)", function()
	it("warns on the first shrinking round only", function()
		local from = Config.Shrink.fromRound
		if from == math.huge then
			return -- shrinking is off in this preset
		end
		local function subtitle(round: number): string
			local model = intro(round)
			HudModel.applyTarget(
				model,
				{ seq = round, colorId = 1, name = Config.Colors[1].name },
				NOW
			)
			return (BannerModel.view(model, NOW) :: any).subtitle
		end
		expect(string.find(subtitle(from), "Tiles are shrinking!", 1, true) ~= nil).toBe(true)
		expect(string.find(subtitle(from + 1), "Tiles are shrinking!", 1, true)).toBe(nil)
	end)
end)

describe("BannerModel other states", function()
	it("shows no banner outside Intermission and RoundIntro", function()
		for _, state in { "Lobby", "Run", "Elimination", "RoundEnd", "Victory", "Reset" } do
			local model = intro(3)
			HudModel.applyState(model, { state = state, endsAt = NOW + 3, duration = 3 })
			expect(BannerModel.view(model, NOW)).toBe(nil)
		end
	end)
end)
