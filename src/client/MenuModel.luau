--!strict
-- What the menu overlay shows, kept pure so it can be tested outside Studio (D-16).
-- The client only reads the role the server set; it never decides it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)
local Util = require(ReplicatedStorage.Shared.Util)

type MatchState = Types.MatchState

export type View = {
	menu: boolean, -- the menu overlay and the orbiting camera
	leave: boolean, -- the Leave button
	hud: boolean, -- the in-round HUD
}

-- One color and shape pair on the how-to-play card.
export type Pair = { colorId: number, name: string, label: string, shape: Types.ShapeId }

local MenuModel = {}

-- The how-to-play card text (D-09). The tagline is from the concept board.
MenuModel.TAGLINE = "Find the color. Survive the chaos. Be the last one!"
MenuModel.STEPS = {
	"1  Watch the target at the top",
	"2  Run to a matching tile in time",
	"3  The rest drop. Last one standing wins!",
}

-- Every palette color with its shape, in palette order, for the pairs on the how-to-play card.
-- label is the color name shown under each tile; name is the full "Red Heart".
function MenuModel.pairs(colors: { Types.ColorDef }): { Pair }
	local list: { Pair } = {}
	for _, colorDef in colors do
		table.insert(list, {
			colorId = colorDef.id,
			name = Util.displayName(colorDef),
			label = colorDef.name,
			shape = colorDef.shape,
		})
	end
	return list
end

-- `role` is the MatchRole attribute (nil before the server sets it, which counts as the menu).
function MenuModel.view(role: string?, state: MatchState?): View
	local inMenu = role == nil or role == "Menu"
	local beforeMatch = state == "Lobby" or state == "Intermission"
	return {
		menu = inMenu,
		leave = role == "Lobby" and beforeMatch,
		hud = not inMenu,
	}
end

-- The camera position on the orbit after `elapsed` seconds, as { x, y, z }.
function MenuModel.orbitPosition(
	center: { number },
	radius: number,
	height: number,
	secondsPerTurn: number,
	elapsed: number
): { number }
	local angle = (elapsed / secondsPerTurn) * 2 * math.pi
	return {
		center[1] + math.cos(angle) * radius,
		center[2] + height,
		center[3] + math.sin(angle) * radius,
	}
end

return MenuModel
