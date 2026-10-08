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
}

export type ConfigType = {
	Colors: { ColorDef },
	Arena: {
		gridSize: number,
		tileSize: number,
	},
	Match: {
		minPlayers: number,
		studioMinPlayers: number,
		studioSinglePlayerEnabled: boolean,
		intermissionSeconds: number,
	},
	StateSeconds: {
		RoundIntro: number,
		Elimination: number,
		RoundEnd: number,
		Victory: number,
		Reset: number,
	},
	Difficulty: { DifficultyRow },
}

return {}
