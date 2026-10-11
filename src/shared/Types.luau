--!strict
-- Shared type definitions. Remote payload types are added with the remotes.

export type ColorId = number

export type RGB = { number }

-- Each color is paired 1:1 with a shape, so players never rely on color alone.
export type ShapeId = "heart" | "triangle" | "star" | "circle" | "square" | "diamond"

export type ColorDef = {
	id: ColorId,
	name: string,
	hex: string, -- "#RRGGBB", exactly as in art/palette.json
	shape: ShapeId,
}

export type DifficultyRow = {
	firstRound: number,
	lastRound: number?,
	timerStart: number,
	timerEnd: number,
	colorCount: number,
	-- Reveal-then-hide (D-05): the target shows for this many seconds at the start of Run,
	-- then hides. nil means the target stays visible all round.
	revealSeconds: number?,
}

export type MatchState =
	"Lobby"
	| "Intermission"
	| "RoundIntro"
	| "Run"
	| "Elimination"
	| "RoundEnd"
	| "Victory"
	| "Reset"

-- Where a player belongs right now. Survivors are on the arena, spectators wait to the side.
-- Menu: has not pressed Play (or pressed Leave), has no character and is not queued.
export type PlayerRole = "Menu" | "Lobby" | "Survivor" | "Spectator"

export type RoundParams = {
	round: number,
	timerSeconds: number,
	colorCount: number,
	targetColorId: ColorId,
	colorIds: { ColorId },
	minTargetTiles: number,
	revealSeconds: number?, -- nil: target visible all round
	tileScale: number, -- tile width as a fraction of the grid cell (D-10); 1 is full size
}

-- How one scenery prop stops a player (Config.Props). "box" fills the prop's footprint
-- less `inset`, "cylinder" is an upright post of `radius` on its centre line, and "posts"
-- is one box down each side, leaving the middle open to walk through.
export type PropRule = {
	kind: "box" | "cylinder" | "posts",
	radius: number,
	postWidth: number,
	postDepth: number,
	inset: number,
}

export type ConfigType = {
	activePreset: string, -- "normal" or "demo"; see the presets in Config
	Colors: { ColorDef },
	Arena: {
		gridSize: number,
		tileSize: number,
		tileHeight: number,
		origin: { number },
	},
	Match: {
		minPlayers: number,
		studioMinPlayers: number,
		studioSinglePlayerEnabled: boolean,
		intermissionSeconds: number,
		maxRounds: number,
		pollSeconds: number,
	},
	StateSeconds: {
		RoundIntro: number,
		Elimination: number,
		RoundEnd: number,
		Victory: number,
		Reset: number,
	},
	Placement: {
		lobbyOrigin: { number },
		spectatorOrigin: { number },
		placeholderSpawnCount: number,
		placeholderColumns: number,
		spawnSpacing: number,
		platformMargin: number,
		platformThickness: number,
		spawnHeight: number,
		lobbyRgb: { number },
		spectatorRgb: { number },
		lobbyCheckRadius: number,
		characterReadyTimeout: number,
		lobbySpawnSize: { number },
	},
	Elimination: {
		fallMargin: number,
		edgeTolerance: number,
		replayTimerBonus: number,
		logDecisions: boolean,
	},
	Hud: {
		margin: number,
		gap: number,
		roundBadgeSize: { number },
		playersBadgeSize: { number },
		targetCardSize: { number },
		statusSize: { number },
		statusY: number,
		timerSize: { number },
		timerBottom: number,
		timerStates: { MatchState },
		warningSeconds: number,
		pulseHz: number,
		pulseScale: number,
		minTextSize: number,
		maxTextSize: number,
		padding: number,
		cornerRadius: number,
		strokeThickness: number,
		headingFont: string,
		bodyFont: string,
		fallbackFont: string,
		panelTransparency: number,
		panelRgb: { number },
		panelStrokeRgb: { number },
		panelStrokeThickness: number,
		strokeRgb: { number },
		textRgb: { number },
		timerTrackRgb: { number },
		timerFillRgb: { number },
		warningRgb: { number },
		hiddenText: string,
		untintedRgb: { number },
		decimalBelowSeconds: number,
		maxWinnerNames: number,
	},
	Lobby: {
		margin: number,
		panelSize: { number },
		topSize: { number },
		centerY: number,
		leaveWidth: number,
		leaveAspect: number,
	},
	Touch: {
		minButtonPixels: number,
	},
	Spectate: {
		dimTransparency: number,
		dimRgb: { number },
		cardSize: { number },
		barSize: { number },
		barBottom: number,
		buttonRgb: { number },
		quietButtonRgb: { number },
		eliminatedRgb: { number },
		spectateButtonSize: { number },
		barMinPixels: { number },
	},
	Results: {
		size: { number },
		centerY: number,
		maxRows: number,
		headerShare: number,
		subtitleShare: number,
		placeShare: number,
		detailShare: number,
		selfRgb: { number },
		winnerRgb: { number },
	},
	Banner: {
		size: { number },
		centerY: number,
		titleShare: number,
		popSeconds: number,
		popStartScale: number,
		fadeSeconds: number,
		maxTitleSize: number,
		maxSubtitleSize: number,
		finalRgb: { number },
		replayRgb: { number },
	},
	Look: {
		lighting: {
			clockTime: number,
			brightness: number,
			ambientRgb: { number },
			outdoorAmbientRgb: { number },
			environmentDiffuseScale: number,
			environmentSpecularScale: number,
			exposureCompensation: number,
		},
		atmosphere: {
			density: number,
			offset: number,
			haze: number,
			glare: number,
			colorRgb: { number },
			decayRgb: { number },
		},
		bloom: { intensity: number, size: number, threshold: number },
		colorCorrection: { saturation: number, contrast: number, brightness: number },
		tile: {
			reflectance: number,
			glossTransparency: number,
			baseDepth: number,
			baseShade: number,
			baseShadeRgb: { number },
		},
		props: {
			count: number,
			radius: number,
			pillarSize: { number },
			ballDiameter: number,
			topBelowArena: number,
		},
		platformReflectance: number,
		shadow: {
			sceneryMinPartSize: number,
			tiles: boolean,
			props: boolean,
		},
		confetti: { pieces: number, seconds: number, sizePixels: number },
	},
	Audio: {
		sfxVolume: number,
		musicVolume: number,
		musicFadeSeconds: number,
		tickFinalPitch: number,
		hidePitch: number,
		logCues: boolean,
	},
	-- Roblox asset IDs. 0 means not uploaded yet: the UI shows a text fallback instead.
	Assets: {
		Sounds: {
			click: number,
			tick: number,
			roundStart: number,
			reveal: number,
			tileDrop: number,
			fall: number,
			eliminated: number,
			survived: number,
			winFanfare: number,
			lobbyMusic: number,
			matchMusic: number,
		},
		Images: {
			shapeIcon: { [ShapeId]: number },
			shapeTile: { [ShapeId]: number },
			leave: number,
			play: number,
			logo: number,
			loadingArt: number,
			sadFace: number,
			eye: number,
			crown: number,
			player: number,
			stopwatch: number,
			tileGloss: number,
			confetti: number,
			sky: {
				back: number,
				down: number,
				front: number,
				left: number,
				right: number,
				up: number,
			},
		},
	},
	Leaderboard: {
		storeKey: string,
		topCount: number,
		refreshSeconds: number,
		maxNameLength: number,
		title: string,
		emptyMessage: string,
		offlineMessage: string,
		offset: { number },
		yaw: number,
		size: { number },
		thickness: number,
		backdropRgb: { number },
		backdropTransparency: number,
		titleRgb: { number },
		textRgb: { number },
	},
	Props: { [string]: PropRule },
	Loading: {
		minSeconds: number,
		fadeSeconds: number,
		preloadTimeoutSeconds: number,
		tipSeconds: number,
		backdropRgb: { number },
		textRgb: { number },
		barRgb: { number },
		barTrackRgb: { number },
		barTrackTransparency: number,
		barHeight: number,
		barWidth: number,
		barY: number,
		logoSize: { number },
		logoY: number,
	},
	Queue: {
		requestCooldown: number,
		respawnSeconds: number,
	},
	Menu: {
		orbitRadius: number,
		orbitHeight: number,
		orbitLookHeight: number,
		orbitSecondsPerTurn: number,
		backdropTransparency: number,
		backdropRgb: { number },
		logoPosition: { number },
		logoSize: { number },
		buttonsX: number,
		playY: number,
		playWidth: number,
		playAspect: number,
		soonSize: { number },
		soonGap: number,
		soonTransparency: number,
		settingsRgb: { number },
		shopRgb: { number },
		leaderboardRgb: { number },
		leaderboardPanelSize: { number },
		leaderboardRowHeight: number,
		howToSize: { number },
		howToCorner: { number },
		buttonRgb: { number },
		leaveRgb: { number },
		textRgb: { number },
		maxTextSize: number,
		cornerRadius: number,
	},
	Shrink: {
		fromRound: number,
		step: number,
		minScale: number,
	},
	Fairness: {
		playersPerTargetTile: number,
	},
	Reveal: {
		minSeconds: number,
		shorterFromRound: number,
	},
	Difficulty: { DifficultyRow },
	Data: {
		dataStoreKey: string,
		maxRetries: number,
		retryDelaySeconds: number,
		Session: {
			heldElsewhereMessage: string,
			takenOverMessage: string,
			startTimeoutSeconds: number,
		},
	},
	Rewards: {
		coinsPerRound: number,
		coinsPerWin: number,
	},
}

-- Player profile schema for DataStore persistence and local stats display.
export type PlayerProfile = {
	wins: number,
	roundsSurvived: number,
	matchesPlayed: number,
	coins: number,
}

-- Remote payloads, server to client. endsAt is a server timestamp from
-- workspace:GetServerTimeNow(), so clients count down without deciding timing.

-- duration is the state's full length in seconds (nil when it has no timer), so the HUD can
-- draw how much of it is left even for a player who joins part way through.
export type StateChangedPayload = {
	state: MatchState,
	endsAt: number?,
	duration: number?,
}

-- seq goes up by one for every RoundIntro, replays included, so a client can tell which
-- round a TargetAnnounced belongs to even if the two remotes arrive out of order.
export type RoundInfoPayload = {
	seq: number,
	round: number,
	timerSeconds: number,
	playersLeft: number,
	revealSeconds: number?, -- set in reveal-then-hide rounds
	colorCount: number, -- colors on the arena this round
	replay: boolean, -- this round is a replay after everyone fell
}

-- In reveal-then-hide rounds this is sent when Run starts, with revealUntil (a server time)
-- after which the HUD hides the target until Run ends.
export type TargetAnnouncedPayload = {
	seq: number,
	colorId: ColorId,
	name: string,
	revealUntil: number?,
	revealSeconds: number?, -- so each client shows it at least this long after it arrives
}

-- The join queue (D-13): players who pressed Play, and how many a match needs to start.
export type LobbyInfoPayload = {
	queued: number,
	needed: number,
}

export type PlayerEliminatedPayload = {
	userId: number,
	playersLeft: number,
}

-- Winners in the same order in both lists. Names are display names, sent by the server so
-- the announcement still works if a winner leaves before a client reads it.
-- One player's result for the match that just ended (D-15). place is nil for a player who
-- left the game; players out in the same round share a place.
export type Standing = {
	userId: number,
	name: string,
	place: number?,
	roundsSurvived: number,
	winner: boolean,
	left: boolean,
}

export type MatchResultPayload = {
	winnerUserIds: { number },
	winnerNames: { string },
	standings: { Standing }, -- best first
	rounds: number, -- rounds played in the match
}

export type PlayerDataPayload = {
	profile: PlayerProfile,
}

-- One line of the top players board (A-04). Tied players share a place.
export type LeaderboardRow = {
	place: number,
	name: string,
	wins: number,
}

-- The top players, sent to every client so the menu panel and the board in the lobby show
-- the same thing. `offline` means the DataStore could not be reached, which is not the same
-- as nobody having won yet: the panel says so rather than showing an empty board.
export type LeaderboardPayload = {
	rows: { LeaderboardRow },
	offline: boolean,
}

return {}
