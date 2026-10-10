--!strict
-- Standings for the match that just ended (D-15): place and rounds survived for everyone who
-- played. Pure, so it can be tested. Nothing is saved; the server builds this once at Victory.

local Types = require(game:GetService("ReplicatedStorage").Shared.Types)

type Standing = Types.Standing

-- A player who went out: eliminated at the end of `round`, or left the game during `round`.
export type Out = { userId: number, name: string, round: number, left: boolean }

export type Player = { userId: number, name: string }

local MatchResults = {}

local function byName(
	a: { name: string, userId: number },
	b: { name: string, userId: number }
): boolean
	if a.name ~= b.name then
		return a.name < b.name
	end
	return a.userId < b.userId
end

-- Winners first (all 1st, credited with every round played), then eliminated players by how
-- late they went out, sharing a place when out in the same round (1st, 2nd, 2nd, 4th), then
-- players who left, with no place. Rounds survived is the round someone went out in minus 1.
function MatchResults.build(winners: { Player }, outs: { Out }, lastRound: number): { Standing }
	local standings: { Standing } = {}

	local sortedWinners = table.clone(winners)
	table.sort(sortedWinners, byName)
	for _, winner in sortedWinners do
		table.insert(standings, {
			userId = winner.userId,
			name = winner.name,
			place = 1,
			roundsSurvived = lastRound,
			winner = true,
			left = false,
		})
	end

	local eliminated: { Out } = {}
	local leavers: { Out } = {}
	for _, out in outs do
		table.insert(if out.left then leavers else eliminated, out)
	end
	local function laterFirst(a: Out, b: Out): boolean
		if a.round ~= b.round then
			return a.round > b.round
		end
		return byName(a, b)
	end
	table.sort(eliminated, laterFirst)
	table.sort(leavers, laterFirst)

	for index, out in eliminated do
		-- Competition ranking: the place is one more than everyone ranked strictly above.
		local above = #sortedWinners
		for other = 1, index - 1 do
			if eliminated[other].round > out.round then
				above += 1
			end
		end
		table.insert(standings, {
			userId = out.userId,
			name = out.name,
			place = above + 1,
			roundsSurvived = math.max(0, out.round - 1),
			winner = false,
			left = false,
		})
	end

	for _, out in leavers do
		table.insert(standings, {
			userId = out.userId,
			name = out.name,
			place = nil,
			roundsSurvived = math.max(0, out.round - 1),
			winner = false,
			left = true,
		})
	end
	return standings
end

return MatchResults
