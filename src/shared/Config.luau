--!strict
-- Every tunable number lives here. Data only, no Roblox services, so it can be
-- loaded in plain Luau tests.

local Types = require(script.Parent.Types)
local Util = require(script.Parent.Util)

local Config: Types.ConfigType = {
	-- Placeholder palette. Replaced by the artist's approved palette before slice 2.
	-- Ids 1 to 6 are reserved so shapes can attach to them later.
	Colors = {
		{ id = 1, name = "Red", rgb = { 235, 64, 52 } },
		{ id = 2, name = "Blue", rgb = { 52, 120, 235 } },
		{ id = 3, name = "Green", rgb = { 60, 190, 80 } },
		{ id = 4, name = "Yellow", rgb = { 250, 215, 50 } },
		{ id = 5, name = "Purple", rgb = { 150, 80, 210 } },
		{ id = 6, name = "Orange", rgb = { 245, 140, 40 } },
	},

	Arena = {
		gridSize = 6,
		tileSize = 10, -- studs
	},

	Match = {
		minPlayers = 2,
		studioMinPlayers = 1,
		-- Studio test flag: when true, a one-player match is allowed in Studio only.
		studioSinglePlayerEnabled = false,
		intermissionSeconds = 10,
		-- How often waiting states check for cancellation, in seconds.
		pollSeconds = 0.25,
	},

	-- Durations of the non-Run states, in seconds. Placeholder values, tune in playtests.
	StateSeconds = {
		RoundIntro = 3,
		Elimination = 3,
		RoundEnd = 2,
		Victory = 5,
		Reset = 2,
	},

	-- Draft values from SPEC section 5. lastRound = nil means open-ended.
	-- The timer moves linearly from timerStart to timerEnd across the row's rounds.
	Difficulty = {
		{ firstRound = 1, lastRound = 3, timerStart = 10, timerEnd = 8, colorCount = 3 },
		{ firstRound = 4, lastRound = 6, timerStart = 7, timerEnd = 6, colorCount = 4 },
		{ firstRound = 7, lastRound = 9, timerStart = 5, timerEnd = 5, colorCount = 5 },
		{ firstRound = 10, lastRound = nil, timerStart = 4, timerEnd = 4, colorCount = 6 },
	},
}

return Util.deepFreeze(Config)
