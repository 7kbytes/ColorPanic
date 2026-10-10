local Harness = require("./harness")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local LobbyModel = Harness.requireModule("StarterPlayer.StarterPlayerScripts.Client.LobbyModel")

describe("LobbyModel.view", function()
	it("is hidden in the menu", function()
		expect(LobbyModel.view("Menu", "Lobby", { queued = 1, needed = 2 })).toBe(nil)
		expect(LobbyModel.view(nil, "Lobby", nil)).toBe(nil)
	end)

	it("counts down the players still needed", function()
		local view = LobbyModel.view("Lobby", "Lobby", { queued = 1, needed = 2 }) :: any
		expect(view.title).toBe("Lobby")
		expect(view.count).toBe("1 player ready")
		expect(view.status).toBe("Waiting for 1 more")
		expect((LobbyModel.view("Lobby", "Lobby", { queued = 1, needed = 4 }) :: any).status).toBe(
			"Waiting for 3 more"
		)
	end)

	it("says the match is about to start once enough players are ready", function()
		local view = LobbyModel.view("Lobby", "Lobby", { queued = 3, needed = 2 }) :: any
		expect(view.count).toBe("3 players ready")
		expect(view.status).toBe("Starting soon")
	end)

	it("keeps the count during Intermission and leaves the countdown to the banner", function()
		local view = LobbyModel.view("Lobby", "Intermission", { queued = 2, needed = 2 }) :: any
		expect(view.count).toBe("2 players ready")
		expect(view.status).toBe("Get ready!")
	end)

	it("waits for the first LobbyInfo without showing a count", function()
		local view = LobbyModel.view("Lobby", "Lobby", nil) :: any
		expect(view.count).toBe(nil)
		expect(view.status).toBe("Waiting for players")
	end)

	it("tells a spectator they play next match, in any state", function()
		for _, state in { "RoundIntro", "Run", "Victory", "Lobby" } do
			local view = LobbyModel.view("Spectator", state, { queued = 3, needed = 2 }) :: any
			expect(view.title).toBe("Next match")
			expect(view.count).toBe(nil)
		end
	end)

	it("is hidden for a survivor and for the lobby role during a match", function()
		expect(LobbyModel.view("Survivor", "Run", { queued = 2, needed = 2 })).toBe(nil)
		expect(LobbyModel.view("Lobby", "Run", { queued = 2, needed = 2 })).toBe(nil)
	end)
end)

describe("LobbyModel.formatReady", function()
	it("uses the singular for one player", function()
		expect(LobbyModel.formatReady(1)).toBe("1 player ready")
		expect(LobbyModel.formatReady(0)).toBe("0 players ready")
		expect(LobbyModel.formatReady(2)).toBe("2 players ready")
	end)
end)
