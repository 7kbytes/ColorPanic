--!strict
-- Every tunable number lives here. Data only, no Roblox services, so it can be
-- loaded in plain Luau tests.

local Types = require(script.Parent.Types)
local Util = require(script.Parent.Util)

-- Which preset to apply on top of the normal values below. "normal" changes nothing.
local ACTIVE_PRESET = "demo"

-- Presets list only the values that differ from normal. Nested tables merge field by field;
-- lists such as Difficulty are replaced whole. See Util.applyOverrides.
local PRESETS: { [string]: { [string]: any } } = {
	normal = {},

	-- Demo build: a short intermission, quicker early rounds and a cap of 8 rounds, so a
	-- match takes about 3 minutes even if nobody falls. Draft values, tune in playtests.
	demo = {
		Match = {
			intermissionSeconds = 5,
			maxRounds = 8,
		},
		StateSeconds = {
			RoundIntro = 4, -- room for the round intro banner (D-12)
			RoundEnd = 3,
			Victory = 8, -- room for the results panel (D-15)
		},
		Difficulty = {
			{ firstRound = 1, lastRound = 2, timerStart = 14, timerEnd = 14, colorCount = 3 },
			{
				firstRound = 3,
				lastRound = 4,
				timerStart = 12,
				timerEnd = 12,
				colorCount = 4,
				revealSeconds = 2,
			},
			{
				firstRound = 5,
				lastRound = 6,
				timerStart = 10,
				timerEnd = 10,
				colorCount = 5,
				revealSeconds = 2,
			},
			{
				firstRound = 7,
				lastRound = nil,
				timerStart = 9,
				timerEnd = 9,
				colorCount = 6,
				revealSeconds = 2,
			},
		} :: { Types.DifficultyRow },
	},
}

local Config: Types.ConfigType = {
	activePreset = ACTIVE_PRESET,

	-- Final palette from the artist, copied from art/palette.json (a test keeps them in step).
	-- The only place in the game that defines a color, its name, hex or shape.
	Colors = {
		{ id = 1, name = "Red", hex = "#E8383D", shape = "heart" },
		{ id = 2, name = "Orange", hex = "#FF8A1F", shape = "triangle" },
		{ id = 3, name = "Yellow", hex = "#FFD60A", shape = "star" },
		{ id = 4, name = "Blue", hex = "#3FB6F0", shape = "circle" },
		{ id = 5, name = "Purple", hex = "#5B4BDB", shape = "square" },
		{ id = 6, name = "Pink", hex = "#D6339F", shape = "diamond" },
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
		-- Last round of a match; everyone still standing after it shares the win.
		-- math.huge means no cap: the match runs until one survivor is left.
		maxRounds = math.huge,
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
		-- Log one line per survivor at RoundEnd saying why they were judged safe or out.
		logDecisions = true,
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

	-- Join queue (D-16). Players start in the menu; only queued players count toward a match.
	Queue = {
		requestCooldown = 1, -- seconds between Play or Leave requests from one player
		respawnSeconds = 5, -- delay before a queued player who died gets a new character
	},

	-- Menu overlay (D-16). Sizes are fractions of the screen; the camera orbits the arena.
	Menu = {
		orbitRadius = 75, -- studs from the arena centre
		orbitHeight = 40, -- studs above the arena
		orbitSecondsPerTurn = 60,
		backdropTransparency = 0.35,
		backdropRgb = { 20, 20, 40 },
		titleSize = { 0.8, 0.18 }, -- width, height
		titleY = 0.22, -- vertical centre of the title
		playSize = { 0.32, 0.16 },
		playY = 0.62,
		leaveSize = { 0.16, 0.08 },
		leavePosition = { 0.02, 0.2 }, -- top left corner, clear of the touch controls
		buttonRgb = { 60, 190, 90 },
		leaveRgb = { 200, 70, 70 },
		textRgb = { 255, 255, 255 },
		maxTextSize = 64,
		cornerRadius = 12, -- pixels
	},

	-- At least one target tile per this many surviving players, rounded up (SPEC section 3).
	Fairness = {
		playersPerTargetTile = 2,
	},

	-- Reveal-then-hide (D-05): rounds with revealSeconds show the target at the start of Run
	-- for that long, then hide it until Run ends. Early rounds must reveal for at least
	-- minSeconds (SPEC section 3); from round shorterFromRound the reveal may be shorter.
	Reveal = {
		minSeconds = 2,
		shorterFromRound = 10,
	},

	-- Draft values from SPEC section 5. lastRound = nil means open-ended.
	-- The timer moves linearly from timerStart to timerEnd across the row's rounds.
	-- revealSeconds: reveal-then-hide from round 4, shorter from round 10 (SPEC section 5).
	Difficulty = {
		{ firstRound = 1, lastRound = 3, timerStart = 10, timerEnd = 8, colorCount = 3 },
		{
			firstRound = 4,
			lastRound = 6,
			timerStart = 7,
			timerEnd = 6,
			colorCount = 4,
			revealSeconds = 2,
		},
		{
			firstRound = 7,
			lastRound = 9,
			timerStart = 5,
			timerEnd = 5,
			colorCount = 5,
			revealSeconds = 2,
		},
		{
			firstRound = 10,
			lastRound = nil,
			timerStart = 4,
			timerEnd = 4,
			colorCount = 6,
			revealSeconds = 1.5,
		},
	},
}

local preset = PRESETS[ACTIVE_PRESET]
assert(preset, string.format("Unknown Config preset %q", ACTIVE_PRESET))
Util.applyOverrides(Config :: any, preset)

return Util.deepFreeze(Config)
