local Harness = require("./harness")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local AudioModel = Harness.requireModule("StarterPlayer.StarterPlayerScripts.Client.AudioModel")
local Config = Harness.requireModule("ReplicatedStorage.Shared.Config")

local STANDING = { playing = true, eliminated = false, fell = false, finalRound = false }

local function with(changes: { [string]: any })
	local context = table.clone(STANDING)
	for key, value in changes do
		context[key] = value
	end
	return context
end

local function only(cues: { string }): string?
	expect(#cues <= 1).toBe(true)
	return cues[1]
end

describe("AudioModel.onState", function()
	it("plays the round start, tile drop and fanfare for everyone", function()
		local watcher = with({ playing = false })
		expect(only(AudioModel.onState("RoundIntro", watcher))).toBe("roundStart")
		expect(only(AudioModel.onState("Elimination", watcher))).toBe("tileDrop")
		expect(only(AudioModel.onState("Victory", watcher))).toBe("winFanfare")
	end)

	it("plays survived at RoundEnd for a player still standing", function()
		expect(only(AudioModel.onState("RoundEnd", STANDING))).toBe("survived")
	end)

	it("skips survived for a player who fell, was eliminated or was not playing", function()
		expect(#AudioModel.onState("RoundEnd", with({ fell = true }))).toBe(0)
		expect(#AudioModel.onState("RoundEnd", with({ eliminated = true }))).toBe(0)
		expect(#AudioModel.onState("RoundEnd", with({ playing = false }))).toBe(0)
	end)

	it("skips survived on the final round, which goes to the fanfare", function()
		expect(#AudioModel.onState("RoundEnd", with({ finalRound = true }))).toBe(0)
	end)

	it("plays nothing for the other states", function()
		for _, state in { "Lobby", "Intermission", "Run", "Reset" } do
			expect(#AudioModel.onState(state, STANDING)).toBe(0)
		end
	end)
end)

describe("AudioModel.tick", function()
	local warn = Config.Hud.warningSeconds

	it("ticks once on each of the last seconds of Run", function()
		local ticked = {}
		local last = nil
		-- Ten frames per second over the last 4 seconds.
		for frame = 40, 1, -1 do
			local t = AudioModel.tick("Run", frame / 10, warn, last)
			if t then
				last = t.second
				table.insert(ticked, t.second)
			end
		end
		expect(#ticked).toBe(warn)
		for index, second in ticked do
			expect(second).toBe(warn - index + 1)
		end
	end)

	it("marks only the last tick as final", function()
		expect((AudioModel.tick("Run", 0.5, warn, 2) :: any).final).toBe(true)
		expect((AudioModel.tick("Run", 1.5, warn, 3) :: any).final).toBe(false)
	end)

	it("never ticks outside Run, before the warning or after time is up", function()
		expect(AudioModel.tick("Intermission", 1, warn, nil)).toBe(nil)
		expect(AudioModel.tick("Run", warn + 0.5, warn, nil)).toBe(nil)
		expect(AudioModel.tick("Run", 0, warn, nil)).toBe(nil)
		expect(AudioModel.tick(nil, 1, warn, nil)).toBe(nil)
	end)
end)

describe("AudioModel.music", function()
	it("plays the lobby track in the menu and between matches", function()
		expect(AudioModel.music("Run", "Menu")).toBe("lobbyMusic")
		expect(AudioModel.music("Run", nil)).toBe("lobbyMusic")
		for _, state in { "Lobby", "Intermission", "Reset" } do
			expect(AudioModel.music(state, "Lobby")).toBe("lobbyMusic")
		end
	end)

	it("plays the match track during a match, for players and spectators", function()
		for _, state in { "RoundIntro", "Run", "Elimination", "RoundEnd", "Victory" } do
			expect(AudioModel.music(state, "Survivor")).toBe("matchMusic")
			expect(AudioModel.music(state, "Spectator")).toBe("matchMusic")
		end
	end)
end)

describe("Config.Assets.Sounds", function()
	it("has an ID for every sound", function()
		for name, id in Config.Assets.Sounds do
			expect(type(id) == "number" and id > 0).toBe(true)
			expect(type(name)).toBe("string")
		end
	end)
end)
