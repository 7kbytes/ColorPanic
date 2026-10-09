--!strict
-- Checks that a match left nothing behind once Reset hands back to the Lobby.
-- Pure: MatchService gathers the numbers, this decides what counts as a leak or stuck state.

export type Snapshot = {
	tileCount: number, -- arena tiles still in the workspace
	survivorCount: number, -- players the match still counts as survivors
	spectatorCount: number, -- players the match still counts as spectators
	partCount: number, -- BaseParts in the workspace, not counting player characters
	baselinePartCount: number, -- the same count before the first match
	outsideLobby: { string }, -- players whose character is somewhere other than the lobby
}

local ResetAudit = {}

-- Returns one message per problem found, or an empty list if the reset was clean.
function ResetAudit.findProblems(snapshot: Snapshot): { string }
	local problems: { string } = {}
	if snapshot.tileCount > 0 then
		table.insert(problems, string.format("%d arena tiles left", snapshot.tileCount))
	end
	if snapshot.survivorCount > 0 then
		table.insert(problems, string.format("%d survivors still tracked", snapshot.survivorCount))
	end
	if snapshot.spectatorCount > 0 then
		table.insert(
			problems,
			string.format("%d spectators still tracked", snapshot.spectatorCount)
		)
	end
	if snapshot.partCount ~= snapshot.baselinePartCount then
		table.insert(
			problems,
			string.format(
				"workspace has %d parts, expected %d",
				snapshot.partCount,
				snapshot.baselinePartCount
			)
		)
	end
	if #snapshot.outsideLobby > 0 then
		table.insert(problems, "not in the lobby: " .. table.concat(snapshot.outsideLobby, ", "))
	end
	return problems
end

return ResetAudit
