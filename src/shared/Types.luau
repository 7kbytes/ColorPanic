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
	-- Roblox asset IDs. 0 means not uploaded yet: the UI shows a text fallback instead.
	Assets: {
		Images: {
			shapeIcon: { [ShapeId]: number },
			shapeTile: { [ShapeId]: number },
			crown: number,
			player: number,
			stopwatch: number,
		},
	},
	Queue: {
		requestCooldown: number,
		respawnSeconds: number,
	},
	Menu: {
		orbitRadius: number,
		orbitHeight: number,
		orbitSecondsPerTurn: number,
		backdropTransparency: number,
		backdropRgb: { number },
		titleSize: { number },
		titleY: number,
		playSize: { number },
		playY: number,
		leaveSize: { number },
		leavePosition: { number },
		buttonRgb: { number },
		leaveRgb: { number },
		textRgb: { number },
		maxTextSize: number,
		cornerRadius: number,
	},
	Fairness: {
		playersPerTargetTile: number,
	},
	Reveal: {
		minSeconds: number,
		shorterFromRound: number,
	},
	Difficulty: { DifficultyRow },
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

export type PlayerEliminatedPayload = {
	userId: number,
	playersLeft: number,
}

-- Winners in the same order in both lists. Names are display names, sent by the server so
-- the announcement still works if a winner leaves before a client reads it.
export type MatchResultPayload = {
	winnerUserIds: { number },
	winnerNames: { string },
}

return {}
