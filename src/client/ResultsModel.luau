--!strict
-- What the match results panel shows (D-15), kept pure so it can be tested outside Studio.
-- Everything comes from the server's MatchResult; this only turns it into text.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)

export type Row = {
	place: string, -- "1st", or "-" for a player who left
	name: string,
	detail: string, -- "3 rounds", or "left"
	isSelf: boolean,
	winner: boolean,
}

export type View = {
	title: string,
	subtitle: string,
	rows: { Row },
	more: number, -- players not listed, shown as "+N more"
}

local ResultsModel = {}

-- 1st, 2nd, 3rd, 4th ... 11th, 12th, 13th ... 21st, 22nd, 23rd.
function ResultsModel.ordinal(n: number): string
	local lastTwo = n % 100
	if lastTwo >= 11 and lastTwo <= 13 then
		return tostring(n) .. "th"
	end
	local last = n % 10
	local suffix = if last == 1
		then "st"
		elseif last == 2 then "nd"
		elseif last == 3 then "rd"
		else "th"
	return tostring(n) .. suffix
end

local function formatRounds(count: number): string
	return string.format("%d %s", count, if count == 1 then "round" else "rounds")
end

local function toRow(standing: Types.Standing, selfId: number): Row
	return {
		place = if standing.place then ResultsModel.ordinal(standing.place) else "-",
		name = standing.name,
		detail = if standing.left then "left" else formatRounds(standing.roundsSurvived),
		isSelf = standing.userId == selfId,
		winner = standing.winner,
	}
end

-- The panel for `result`, as seen by player `selfId`, listing at most `maxRows` players. If the
-- local player would be cut off, their row takes the last listed place, so everyone sees how
-- they did.
function ResultsModel.view(result: Types.MatchResultPayload, selfId: number, maxRows: number): View
	local winnerCount = #result.winnerNames
	local title: string
	if winnerCount == 1 then
		title = result.winnerNames[1] .. " wins!"
	elseif winnerCount > 1 then
		title = "Shared win!"
	else
		title = "Match over"
	end

	local standings = result.standings
	local rows: { Row } = {}
	local shown = math.min(#standings, maxRows)
	for index = 1, shown do
		table.insert(rows, toRow(standings[index], selfId))
	end
	if #standings > shown and shown > 0 then
		for index = shown + 1, #standings do
			if standings[index].userId == selfId then
				rows[shown] = toRow(standings[index], selfId)
				break
			end
		end
	end

	return {
		title = title,
		subtitle = "Match lasted " .. formatRounds(result.rounds),
		rows = rows,
		more = #standings - shown,
	}
end

return ResultsModel
