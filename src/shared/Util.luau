--!strict
-- Small pure helpers shared by server and client.

local Types = require(script.Parent.Types)

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

-- Converts "#RRGGBB" to { r, g, b } with each value 0 to 255. Errors on any other format,
-- so a bad palette entry fails loudly instead of showing the wrong color.
function Util.hexToRgb(hex: string): { number }
	local r, g, b = string.match(hex, "^#(%x%x)(%x%x)(%x%x)$")
	assert(r and g and b, string.format("Bad hex color %q, expected #RRGGBB", hex))
	return { tonumber(r, 16) :: number, tonumber(g, 16) :: number, tonumber(b, 16) :: number }
end

-- Returns the palette entry with this id, or nil if there is none.
function Util.getColorDef(colors: { Types.ColorDef }, id: Types.ColorId): Types.ColorDef?
	for _, colorDef in colors do
		if colorDef.id == id then
			return colorDef
		end
	end
	return nil
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
