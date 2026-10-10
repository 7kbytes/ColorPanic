local Harness = require("./harness")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local MenuModel = Harness.requireModule("StarterPlayer.StarterPlayerScripts.Client.MenuModel")

describe("MenuModel.view", function()
	it("shows the menu, not the HUD, before the server sets a role", function()
		local view = MenuModel.view(nil, nil)
		expect(view.menu).toBe(true)
		expect(view.hud).toBe(false)
		expect(view.leave).toBe(false)
	end)

	it("shows the menu for the Menu role, during any state", function()
		for _, state in { "Lobby", "Run", "Victory" } do
			local view = MenuModel.view("Menu", state)
			expect(view.menu).toBe(true)
			expect(view.hud).toBe(false)
			expect(view.leave).toBe(false)
		end
	end)

	it("shows Leave in the lobby before a match, with the HUD", function()
		for _, state in { "Lobby", "Intermission" } do
			local view = MenuModel.view("Lobby", state)
			expect(view.menu).toBe(false)
			expect(view.leave).toBe(true)
			expect(view.hud).toBe(true)
		end
	end)

	it("hides Leave during a match and for survivors and spectators", function()
		expect(MenuModel.view("Lobby", "Reset").leave).toBe(false)
		expect(MenuModel.view("Survivor", "Run").leave).toBe(false)
		expect(MenuModel.view("Spectator", "Intermission").leave).toBe(false)
	end)
end)

describe("MenuModel.orbitPosition", function()
	local CENTER = { 0, 40, 0 }

	it("starts on the +X side at the given height", function()
		local p = MenuModel.orbitPosition(CENTER, 75, 40, 60, 0)
		expect(p[1]).toBeCloseTo(75)
		expect(p[2]).toBeCloseTo(80)
		expect(p[3]).toBeCloseTo(0)
	end)

	it("is a quarter turn round after a quarter of the period", function()
		local p = MenuModel.orbitPosition(CENTER, 75, 40, 60, 15)
		expect(p[1]).toBeCloseTo(0)
		expect(p[3]).toBeCloseTo(75)
	end)

	it("stays at the orbit radius", function()
		for _, t in { 3, 17, 42, 61 } do
			local p = MenuModel.orbitPosition(CENTER, 75, 40, 60, t)
			expect(math.sqrt(p[1] ^ 2 + p[3] ^ 2)).toBeCloseTo(75)
		end
	end)
end)

describe("MenuModel how-to-play card (D-09)", function()
	local Config = Harness.requireModule("ReplicatedStorage.Shared.Config")
	local Util = Harness.requireModule("ReplicatedStorage.Shared.Util")

	it("lists every palette color with its shape, in palette order", function()
		local pairsList = MenuModel.pairs(Config.Colors)
		expect(#pairsList).toBe(#Config.Colors)
		for index, colorDef in Config.Colors do
			local pair = pairsList[index]
			expect(pair.colorId).toBe(colorDef.id)
			expect(pair.shape).toBe(colorDef.shape)
			expect(pair.label).toBe(colorDef.name)
			expect(pair.name).toBe(Util.displayName(colorDef))
		end
	end)

	it("has a tagline and three steps", function()
		expect(#MenuModel.TAGLINE > 0).toBe(true)
		expect(#MenuModel.STEPS).toBe(3)
	end)
end)
