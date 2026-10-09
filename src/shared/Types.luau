--!strict
-- Shared type definitions. Remote payload types are added with the remotes.

export type ColorId = number

export type RGB = { number }

export type ColorDef = {
	id: ColorId,
	name: string,
	rgb: RGB,
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

export type RoundParams = {
	round: number,
	timerSeconds: number,
	colorCount: number,
	targetColorId: ColorId,
	colorIds: { ColorId },
	minTargetTiles: number,
}

export type ConfigType = {
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
		pollSeconds: number,
	},
	StateSeconds: {
		RoundIntro: number,
		Elimination: number,
		RoundEnd: number,
		Victory: number,
		Reset: number,
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

export type MatchResultPayload = {
	winnerUserIds: { number },
}

return {}
