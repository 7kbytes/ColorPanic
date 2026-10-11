--!strict
-- The all-time top players board: ranking, ties and the text on each row.
-- Pure, so it is tested outside Studio. LeaderboardService does the DataStore work.

local LeaderboardRules = {}

-- One entry as it comes back from the OrderedDataStore, after the user id is resolved.
export type Entry = {
	userId: number,
	name: string,
	wins: number,
}

-- One row as it is drawn on the board.
export type Row = {
	place: number, -- shared by tied players
	name: string,
	wins: number,
}

-- Sorts entries best first and assigns places, with ties sharing a place.
--
-- Two players on 9 wins are both 2nd, and the next is 4th, which is how the match results
-- panel already reads. The OrderedDataStore returns its own order, but it is re-sorted here
-- so ties break the same way every time: by name, so the board does not reshuffle between
-- refreshes for no visible reason.
function LeaderboardRules.rank(entries: { Entry }, topCount: number): { Row }
	local sorted = table.clone(entries)
	table.sort(sorted, function(a, b)
		if a.wins ~= b.wins then
			return a.wins > b.wins
		end
		if a.name ~= b.name then
			return a.name < b.name
		end
		return a.userId < b.userId
	end)

	local rows: { Row } = {}
	local place = 0
	local lastWins: number? = nil
	for index, entry in sorted do
		if index > topCount then
			break
		end
		if entry.wins ~= lastWins then
			place = index -- a tie shares the earlier place, the next one skips ahead
			lastWins = entry.wins
		end
		table.insert(rows, { place = place, name = entry.name, wins = entry.wins })
	end
	return rows
end

-- Shortens a name that will not fit the board, keeping the start, which is the part people
-- recognise. Roblox names are at most 20 characters, display names can be longer.
function LeaderboardRules.shortName(name: string, maxLength: number): string
	if maxLength <= 0 then
		return ""
	end
	if utf8.len(name) == nil then
		return name -- not valid UTF-8, leave it rather than cutting mid character
	end
	if (utf8.len(name) :: number) <= maxLength then
		return name
	end
	local offset = utf8.offset(name, maxLength)
	return if offset then string.sub(name, 1, offset - 1) .. "..." else name
end

-- The text for one row, for example "1.  luxygee" and "12".
function LeaderboardRules.rowText(row: Row, maxNameLength: number): (string, string)
	local left =
		string.format("%d.  %s", row.place, LeaderboardRules.shortName(row.name, maxNameLength))
	return left, tostring(row.wins)
end

-- The message to show instead of rows, or nil when there are rows to show.
--
-- "Nobody has won yet" and "we could not reach the store" look the same on an empty board
-- and mean completely different things, so they are told apart here.
function LeaderboardRules.statusMessage(
	offline: boolean,
	rowCount: number,
	offlineText: string,
	emptyText: string
): string?
	if offline then
		return offlineText
	end
	if rowCount == 0 then
		return emptyText
	end
	return nil
end

-- Whether a player's new win total is worth writing.
--
-- The store only holds a player's best total, and wins only ever go up, so a write is
-- skipped unless the number actually changed. Nothing here is worth spending request
-- budget on twice.
function LeaderboardRules.needsWrite(storedWins: number?, currentWins: number): boolean
	if currentWins <= 0 then
		return false -- nobody with no wins belongs on an all-time wins board
	end
	return storedWins == nil or currentWins > storedWins
end

-- Drops anything the store should not show: zero or negative scores, and entries whose
-- name could not be resolved. A board is public, so it shows only what it is sure of.
function LeaderboardRules.usable(entries: { Entry }): { Entry }
	local kept = {}
	for _, entry in entries do
		if entry.wins > 0 and entry.name ~= "" then
			table.insert(kept, entry)
		end
	end
	return kept
end

return LeaderboardRules
