--!strict
-- What the menu overlay shows, kept pure so it can be tested outside Studio (D-16).
-- The client only reads the role the server set; it never decides it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage.Shared.Types)

type MatchState = Types.MatchState

export type View = {
	menu: boolean, -- the menu overlay and the orbiting camera
	leave: boolean, -- the Leave button
	hud: boolean, -- the in-round HUD
}

local MenuModel = {}

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
