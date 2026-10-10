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
-- The tile art asset ID for a palette color, looked up through the color's shape. nil when the
-- color is unknown or its art has no ID yet (0).
function Util.getTileImageId(
	colors: { Types.ColorDef },
	shapeTiles: { [Types.ShapeId]: number },
	id: Types.ColorId
): number?
	local colorDef = Util.getColorDef(colors, id)
	local imageId = if colorDef then shapeTiles[colorDef.shape] else nil
	return if imageId and imageId ~= 0 then imageId else nil
end

function Util.getColorDef(colors: { Types.ColorDef }, id: Types.ColorId): Types.ColorDef?
	for _, colorDef in colors do
		if colorDef.id == id then
			return colorDef
		end
	end
	return nil
end

-- A non-empty array. An empty table counts as "no changes", not as an empty list.
local function isList(value: { [any]: any }): boolean
	return #value > 0
end

-- Writes `overrides` into `target` in place and returns `target`. Nested tables are merged
-- field by field; lists (such as the difficulty table) are replaced whole. Every overridden
-- key must already exist in `target` with the same type, so a typo in a preset fails loudly.
function Util.applyOverrides(target: { [string]: any }, overrides: { [string]: any }, path: string?)
	for key, value in overrides do
		local where = if path then path .. "." .. key else key
		local current = target[key]
		assert(current ~= nil, string.format("Preset sets unknown Config key %s", where))
		assert(
			type(current) == type(value),
			string.format(
				"Preset sets %s to a %s, Config has a %s",
				where,
				type(value),
				type(current)
			)
		)
		if type(value) == "table" and not isList(value) then
			Util.applyOverrides(current, value, where)
		else
			target[key] = value
		end
	end
	return target
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
