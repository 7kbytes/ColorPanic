--!strict
-- Small pure helpers shared by server and client.

local Util = {}

-- Recursively freezes a table so accidental writes raise an error.
function Util.deepFreeze<T>(value: T): T
	if type(value) == "table" then
		for _, child in value :: any do
			Util.deepFreeze(child)
		end
		table.freeze(value :: any)
	end
	return value
end

-- Returns the minimum players needed to start a match. The Studio test flag only
-- lowers the minimum when running in Studio.
function Util.getMinPlayers(
	match: {
		minPlayers: number,
		studioMinPlayers: number,
		studioSinglePlayerEnabled: boolean,
	},
	isStudio: boolean
): number
	if isStudio and match.studioSinglePlayerEnabled then
		return match.studioMinPlayers
	end
	return match.minPlayers
end

return Util
