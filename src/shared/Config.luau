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

	-- In-match HUD (D-06). Sizes are { width, height } fractions of the safe screen area, so it
	-- scales from a 640x360 phone up. The round and players badges sit either side of the target
	-- card, clear of Roblox's chat (top left) and player list (top right). The bottom corners
	-- stay free for the thumbstick and jump button.
	Hud = {
		margin = 0.015, -- gap between the HUD and the top of the screen
		gap = 0.01, -- gap between the target card and the badges beside it
		roundBadgeSize = { 0.15, 0.11 }, -- left of the target card
		playersBadgeSize = { 0.09, 0.11 }, -- right of the target card
		targetCardSize = { 0.28, 0.17 }, -- top centre
		statusSize = { 0.5, 0.07 }, -- centre, under the target card
		statusY = 0.21, -- top of the status line
		timerSize = { 0.42, 0.075 }, -- bottom centre
		timerBottom = 0.03, -- gap under the timer bar
		-- States that show the timer bar. The others show their countdown nowhere.
		timerStates = { "Intermission", "Run" },
		warningSeconds = 3, -- the last seconds of Run turn the timer red and pulse it
		pulseHz = 2,
		pulseScale = 0.08, -- the timer grows by up to this fraction while pulsing
		minTextSize = 10,
		maxTextSize = 36,
		padding = 6, -- pixels inside each panel
		cornerRadius = 14, -- pixels
		strokeThickness = 2, -- pixels of dark outline on HUD text
		-- Enum.Font names. FredokaOne matches the bubbly logo; the fallback is used if a name
		-- is not a font.
		headingFont = "FredokaOne",
		bodyFont = "BuilderSansBold",
		fallbackFont = "BuilderSansBold",
		-- Saturated blue panels with a white outline, as in the concept board (D-09).
		panelTransparency = 0.05,
		panelRgb = { 36, 92, 214 },
		panelStrokeRgb = { 255, 255, 255 },
		panelStrokeThickness = 3, -- pixels
		strokeRgb = { 27, 27, 58 }, -- same ink as the tile outlines
		textRgb = { 255, 255, 255 },
		timerTrackRgb = { 18, 40, 110 },
		timerFillRgb = { 255, 255, 255 },
		warningRgb = { 255, 72, 72 },
		hiddenText = "?", -- target name and icon while the target is secret
		untintedRgb = { 255, 255, 255 }, -- image tint that leaves art as drawn
		-- Below this many seconds the timer shows tenths, above it whole seconds.
		decimalBelowSeconds = 10,
		-- A shared win names at most this many players, then "and N more", so the line fits.
		maxWinnerNames = 3,
	},

	-- Centre banner (D-12) for Intermission and RoundIntro. Same panel style as the HUD.
	Banner = {
		size = { 0.46, 0.22 }, -- { width, height } fractions of the safe screen area
		centerY = 0.45, -- vertical centre, clear of the target card above and timer below
		titleShare = 0.6, -- fraction of the banner height for the title, the rest for the subtitle
		popSeconds = 0.3, -- grow-in time when a new banner appears
		popStartScale = 0.6,
		fadeSeconds = 0.3, -- fade out over the last seconds of its state
		maxTitleSize = 72,
		maxSubtitleSize = 36,
		finalRgb = { 255, 214, 10 }, -- title color for "Final round!"
		replayRgb = { 255, 138, 31 }, -- title color for "Everyone fell!"
	},

	-- Lobby panel (D-13): queue count and status on the left, vertically centred, clear of the
	-- chat (top left), the centre banner and the thumbstick (bottom left). Leave sits under it.
	Lobby = {
		margin = 0.015, -- gap to the screen edge and between the panel and Leave
		panelSize = { 0.22, 0.2 }, -- { width, height } fractions of the safe screen area
		centerY = 0.45,
		leaveWidth = 0.16, -- fraction of the screen width; height follows the button art
		leaveAspect = 512 / 192, -- width / height of the Leave button art
	},

	-- Eliminated card and spectate bar (D-14). Same panel style as the HUD.
	Spectate = {
		dimTransparency = 0.45, -- the backdrop behind the eliminated card
		dimRgb = { 10, 8, 24 },
		cardSize = { 0.4, 0.52 }, -- { width, height } fractions of the safe screen area
		barSize = { 0.5, 0.09 }, -- the "Watching" bar, bottom centre
		barBottom = 0.13, -- gap under the bar, so it sits above the timer bar
		buttonRgb = { 60, 190, 90 }, -- Spectate
		quietButtonRgb = { 90, 84, 130 }, -- Close, Stop and the arrows
		spectateButtonSize = { 0.16, 0.08 }, -- the Spectate button for mid-match joiners
	},

	-- Match results panel (D-15), shown during Victory. Same panel style as the HUD.
	Results = {
		size = { 0.52, 0.66 }, -- { width, height } fractions of the safe screen area
		centerY = 0.5,
		maxRows = 6, -- players listed; the rest show as "+N more"
		headerShare = 0.2, -- fractions of the panel height
		subtitleShare = 0.1,
		placeShare = 0.18, -- fractions of a row's width
		detailShare = 0.3,
		selfRgb = { 86, 150, 245 }, -- background of the local player's row, lighter than the panel
		winnerRgb = { 255, 214, 10 }, -- place text for winners
	},

	-- Arena look (D-07). Visual only: nothing here changes gameplay, collisions or timing.
	-- Draft values, tuned by eye in Studio.
	Look = {
		-- Applied on each client (Lighting.ClockTime does not replicate).
		lighting = {
			clockTime = 14, -- early afternoon
			-- Kept near Roblox's defaults: brighter light and ambient washed Orange toward Yellow in
			-- Studio QA. Tiles must keep their palette hues, so the look comes from haze, bloom,
			-- gloss and props instead.
			brightness = 1.5,
			ambientRgb = { 80, 82, 92 },
			outdoorAmbientRgb = { 128, 130, 140 },
			environmentDiffuseScale = 0.4,
			environmentSpecularScale = 0.3,
			exposureCompensation = 0,
		},
		atmosphere = {
			density = 0.25,
			offset = 0.1,
			haze = 1,
			glare = 0.2,
			colorRgb = { 199, 225, 255 },
			decayRgb = { 120, 160, 220 },
		},
		bloom = { intensity = 0.35, size = 24, threshold = 1.6 }, -- subtle, for phones
		-- Kept small: stronger saturation pushed Blue toward cyan in Studio QA.
		colorCorrection = { saturation = 0.05, contrast = 0.05, brightness = 0 },
		-- Tiles: a little shine, the gloss texture on the sides, and a darker base underneath.
		tile = {
			reflectance = 0.06,
			glossTransparency = 0.7, -- the gloss texture on each side
			baseDepth = 0.8, -- studs of darker block under each tile
			baseShade = 0.45, -- how far the base color moves toward baseShadeRgb
			baseShadeRgb = { 27, 27, 58 },
		},
		-- A ring of lollipop props around the arena (placeholder until the builder's arena).
		props = {
			count = 12,
			radius = 50, -- studs from the arena centre
			pillarSize = { 2, 16, 2 }, -- studs
			ballDiameter = 6,
			topBelowArena = 4, -- studs the ball top sits below the tiles, clear of the view
		},
		platformReflectance = 0.08, -- lobby and spectator platforms
		-- Confetti burst on the screen at Victory, client only.
		confetti = {
			pieces = 36,
			seconds = 3,
			sizePixels = 56, -- the art is a small sparkle burst, so each piece needs room
		},
	},

	-- Audio (D-08). Volumes are 0 to 1. Pitches are Sound.PlaybackSpeed multipliers.
	Audio = {
		sfxVolume = 0.8,
		musicVolume = 0.3,
		musicFadeSeconds = 1, -- crossfade when the music changes
		tickFinalPitch = 1.35, -- the last countdown tick
		hidePitch = 0.8, -- the reveal chime, played lower when the target hides
		logCues = false, -- QA: print every sound as it plays
	},

	-- Roblox Image asset IDs (owner: the game's owner), from "Color Panic Asset IDs.xlsx".
	-- Only the assets the code uses so far; later tasks add theirs. 0 shows a text fallback.
	Assets = {
		-- Roblox Audio asset IDs (S-01 to S-11), owned by the game's owner. 0 skips the sound.
		Sounds = {
			click = 88099638296328,
			tick = 101813031315495,
			roundStart = 98620534814039,
			reveal = 134025852579124,
			tileDrop = 107728816607408,
			fall = 81600766513994,
			eliminated = 119806547942563,
			survived = 113177692622900,
			winFanfare = 136707128772493,
			lobbyMusic = 139403154782279,
			matchMusic = 106478061958089,
		},
		Images = {
			-- White, tinted in game with the palette color (A-02).
			shapeIcon = {
				heart = 123130229675076,
				triangle = 71048495577950,
				star = 104194769717159,
				circle = 127674839088791,
				square = 83189910136901,
				diamond = 101425829907806,
			},
			-- The artist's tile art (A-01): a colored rounded square with the white shape on it.
			-- Drawn on top of each arena tile and on the HUD target card.
			shapeTile = {
				heart = 76075417223764,
				triangle = 99013340642351,
				star = 126829176555251,
				circle = 139221210873915,
				square = 81677246211262,
				diamond = 86763642426459,
			},
			leave = 131161271982260, -- A-09, red "Back" button art used for Leave
			play = 76866923563733, -- A-09, green Play button art
			logo = 107467392816535, -- A-03, title screen logo
			sadFace = 114507417954529, -- A-07, eliminated card
			eye = 92667144225263, -- A-08, spectate bar
			crown = 81195306124170, -- A-04, round badge
			player = 139725380431484, -- A-05, players left
			stopwatch = 112716861247418, -- A-06, timer bar
			tileGloss = 106294149443991, -- A-11, faint gloss on tile sides
			confetti = 96276252812980, -- A-10, Victory confetti
		},
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
		-- Title screen (D-09), laid out like the concept board: logo top left, Play and two
		-- "Coming soon" tiles under it, and a how-to-play card bottom right. The live arena
		-- shows through a light backdrop.
		backdropTransparency = 0.7,
		backdropRgb = { 20, 20, 40 },
		logoPosition = { 0.03, 0.03 }, -- top left corner
		logoSize = { 0.36, 0.32 },
		buttonsX = 0.04, -- left edge of the button column
		playY = 0.38, -- top of the Play button
		playWidth = 0.27, -- the height follows the art
		playAspect = 512 / 192, -- width / height of the Play button art
		soonSize = { 0.22, 0.1 }, -- the Settings and Shop tiles
		soonGap = 0.025, -- vertical gap between the buttons
		soonTransparency = 0.35, -- greyed: not wired yet
		settingsRgb = { 40, 120, 230 },
		shopRgb = { 130, 70, 210 },
		howToSize = { 0.46, 0.58 },
		howToCorner = { 0.97, 0.96 }, -- bottom right corner of the card
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
