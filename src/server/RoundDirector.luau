--!strict
-- Turns a round number into that round's parameters. Pure functions with no side effects
-- and no world state, so they can be unit tested. Randomness comes from the rng argument.

local Types = require(game:GetService("ReplicatedStorage").Shared.Types)

type ColorId = Types.ColorId
type DifficultyRow = Types.DifficultyRow
type RoundParams = Types.RoundParams

local RoundDirector = {}

-- Returns the difficulty row that covers `round`. A row with lastRound = nil is open-ended.
function RoundDirector.getRow(difficulty: { DifficultyRow }, round: number): DifficultyRow
	for _, row in difficulty do
		local lastRound = row.lastRound
		if round >= row.firstRound and (lastRound == nil or round <= lastRound) then
			return row
		end
	end
	error(string.format("No difficulty row covers round %d", round))
end

-- Moves linearly from timerStart on the row's first round to timerEnd on its last round.
-- Open-ended and single-round rows use timerStart.
function RoundDirector.getTimerSeconds(row: DifficultyRow, round: number): number
	local lastRound = row.lastRound
	if lastRound == nil or lastRound == row.firstRound then
		return row.timerStart
	end
	local progress = (round - row.firstRound) / (lastRound - row.firstRound)
	return row.timerStart + (row.timerEnd - row.timerStart) * progress
end

-- Fairness rule: at least one target tile per `playersPerTile` survivors, rounded up,
-- and never fewer than one.
function RoundDirector.getMinTargetTiles(survivors: number, playersPerTile: number): number
	return math.max(1, math.ceil(survivors / playersPerTile))
end

-- Picks this round's colors and target and returns every parameter the round needs.
function RoundDirector.getRoundParams(
	config: Types.ConfigType,
	round: number,
	survivors: number,
	rng: Random
): RoundParams
	local row = RoundDirector.getRow(config.Difficulty, round)

	local ids: { ColorId } = {}
	for _, colorDef in config.Colors do
		table.insert(ids, colorDef.id)
	end
	for i = #ids, 2, -1 do
		local j = rng:NextInteger(1, i)
		ids[i], ids[j] = ids[j], ids[i]
	end

	local colorCount = math.min(row.colorCount, #ids)
	local colorIds: { ColorId } = table.create(colorCount)
	for i = 1, colorCount do
		colorIds[i] = ids[i]
	end

	return {
		round = round,
		timerSeconds = RoundDirector.getTimerSeconds(row, round),
		colorCount = colorCount,
		colorIds = colorIds,
		targetColorId = colorIds[rng:NextInteger(1, colorCount)],
		minTargetTiles = RoundDirector.getMinTargetTiles(
			survivors,
			config.Fairness.playersPerTargetTile
		),
	}
end

return RoundDirector
