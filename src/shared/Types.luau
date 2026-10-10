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
		width: number,
		height: number,
		topMargin: number,
		minTextSize: number,
		maxTextSize: number,
		padding: number,
		backgroundTransparency: number,
		backgroundRgb: { number },
		textRgb: { number },
		decimalBelowSeconds: number,
		maxWinnerNames: number,
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
	Difficulty: { DifficultyRow },
}

-- Remote payloads, server to client. endsAt is a server timestamp from
-- workspace:GetServerTimeNow(), so clients count down without deciding timing.

export type StateChangedPayload = {
	state: MatchState,
	endsAt: number?,
}

export type RoundInfoPayload = {
	round: number,
	timerSeconds: number,
	playersLeft: number,
}

export type TargetAnnouncedPayload = {
	colorId: ColorId,
	name: string,
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
