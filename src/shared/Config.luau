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
		tileHeight = 1, -- studs
		-- Centre of the grid. Placeholder until the builder delivers the arena (slice 2).
		origin = { 0, 40, 0 },
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

	-- Placeholder lobby and spectator areas, used until the builder delivers real ones (slice 2).
	-- Origins are the centre of each platform's top surface. The arena spans z -30 to 30 at
	-- height 40, so the spectator platform sits beside it and above it.
	Placement = {
		lobbyOrigin = { 0, 1, 100 },
		spectatorOrigin = { 0, 50, -60 },
		placeholderSpawnCount = 12,
		placeholderColumns = 4,
		spawnSpacing = 6, -- studs between placeholder spawns
		platformMargin = 6, -- studs of platform around the outer spawns
		platformThickness = 1,
		spawnHeight = 3, -- studs above a spawn or tile top where characters are placed
		lobbyRgb = { 200, 200, 210 },
		spectatorRgb = { 170, 200, 230 },
		-- After a reset, a character further than this from every lobby spawn counts as stuck.
		lobbyCheckRadius = 40, -- studs
		-- How long to wait for a new character to enter the workspace with its root part
		-- before giving up on moving it. A missed move leaves it at the lobby SpawnLocation.
		characterReadyTimeout = 5, -- seconds
		lobbySpawnSize = { 6, 1, 6 }, -- studs, the lobby SpawnLocation fallback
	},

	-- Who counts as eliminated at the end of the Elimination state (SPEC section 3).
	Elimination = {
		fallMargin = 5, -- studs below a tile top before a player counts as fallen
		edgeTolerance = 1, -- studs past a tile edge that still count as standing on it
		replayTimerBonus = 3, -- extra seconds when a round is replayed after everyone fell
	},

	-- Placeholder HUD (S1-09). Sizes are fractions of the screen so it scales to phones.
	Hud = {
		width = 0.4, -- fraction of screen width
		height = 0.25, -- fraction of screen height
		topMargin = 0.01, -- fraction of screen height above the panel
		minTextSize = 10,
		maxTextSize = 28,
		padding = 6, -- pixels inside the panel
		backgroundTransparency = 0.4,
		backgroundRgb = { 20, 20, 30 },
		textRgb = { 255, 255, 255 },
		-- Below this many seconds the timer shows tenths, above it whole seconds.
		decimalBelowSeconds = 10,
		-- A shared win names at most this many players, then "and N more", so the line fits.
		maxWinnerNames = 3,
	},

	-- At least one target tile per this many surviving players, rounded up (SPEC section 3).
	Fairness = {
		playersPerTargetTile = 2,
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
