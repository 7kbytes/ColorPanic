local Harness = require("./harness")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local Config = Harness.requireModule("ReplicatedStorage.Shared.Config")

local LOOK = Config.Look

local function isRgb(rgb): boolean
	if #rgb ~= 3 then
		return false
	end
	for _, channel in rgb do
		if channel < 0 or channel > 255 or channel ~= math.floor(channel) then
			return false
		end
	end
	return true
end

describe("Config.Look", function()
	it("keeps transparencies and shades between 0 and 1", function()
		for _, value in
			{
				LOOK.tile.glossTransparency,
				LOOK.tile.baseShade,
				LOOK.tile.reflectance,
				LOOK.platformReflectance,
				LOOK.atmosphere.density,
			}
		do
			expect(value >= 0 and value <= 1).toBe(true)
		end
	end)

	it("uses valid colors", function()
		for _, rgb in
			{
				LOOK.lighting.ambientRgb,
				LOOK.lighting.outdoorAmbientRgb,
				LOOK.atmosphere.colorRgb,
				LOOK.atmosphere.decayRgb,
				LOOK.tile.baseShadeRgb,
			}
		do
			expect(isRgb(rgb)).toBe(true)
		end
	end)

	it("keeps the clock in a day", function()
		expect(LOOK.lighting.clockTime >= 0 and LOOK.lighting.clockTime < 24).toBe(true)
	end)

	it("keeps the props ring clear of the arena, even at its corners", function()
		local halfDiagonal = Config.Arena.gridSize * Config.Arena.tileSize / 2 * math.sqrt(2)
		expect(LOOK.props.radius - LOOK.props.ballDiameter / 2 > halfDiagonal).toBe(true)
	end)

	it("keeps the props below the tiles, out of the players' view of them", function()
		expect(LOOK.props.topBelowArena > 0).toBe(true)
		expect(LOOK.props.count > 0).toBe(true)
	end)

	it("keeps the confetti burst small", function()
		expect(LOOK.confetti.pieces > 0 and LOOK.confetti.pieces <= 60).toBe(true)
		expect(LOOK.confetti.seconds > 0).toBe(true)
	end)
end)
