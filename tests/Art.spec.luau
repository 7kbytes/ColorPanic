local Harness = require("./harness")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local Config = Harness.requireModule("ReplicatedStorage.Shared.Config")

local ART = Config.Art
local IMAGES = Config.Assets.Images

-- The art pass is nearly all Roblox drawing code, which these tests cannot reach. What they
-- can check is the figures it is driven by, and that two slots are not pointed at one
-- picture, which would look deliberate on screen and be slow to spot by eye.
--
-- There is nothing here about 9-slice rects any more. The painted panels were dropped
-- because a slice rect is in the image's own pixels and Roblox resizes an upload to fit
-- 1024 on its long edge without saying so, which put every rect off the end of its image.
-- The first version of these tests checked the rects against the source PNG sizes, so it
-- passed while the panels rendered as one stretched corner: a test is only as good as the
-- reference it checks against. docs/a10-art-spec.md covers art that would avoid this.

local function isAssetId(value: any): boolean
	return type(value) == "number" and value > 0 and value == math.floor(value)
end

describe("Config.Art figures", function()
	it("has a confetti sheet with a plausible layout", function()
		local sheet = ART.confettiSheet
		expect(sheet.columns >= 1).toBe(true)
		expect(sheet.rows >= 1).toBe(true)
		-- The cells have to divide the sheet evenly, or a piece would show part of its
		-- neighbour.
		expect(sheet.pixels % sheet.columns).toBe(0)
		expect(sheet.pixels % sheet.rows).toBe(0)
	end)

	it("counts up coins over a time a player can see but not wait for", function()
		expect(ART.coinCountSeconds > 0).toBe(true)
		expect(ART.coinCountSeconds < 2).toBe(true)
	end)

	it("sizes the coin badge as a fraction of the screen", function()
		for _, part in ART.coinBadgeSize do
			expect(part > 0).toBe(true)
			expect(part < 1).toBe(true)
		end
	end)

	it("puffs more dust when a tile drops than when a player lands on one", function()
		-- A whole tile falling away is the bigger event of the two.
		expect(ART.Puff.dropCount > ART.Puff.landCount).toBe(true)
		expect(ART.Puff.landCount > 0).toBe(true)
	end)

	it("gives every puff particle a life and a speed, the right way round", function()
		local puff = ART.Puff
		expect(puff.lifetime[1] > 0).toBe(true)
		expect(puff.lifetime[1] <= puff.lifetime[2]).toBe(true)
		expect(puff.speed[1] <= puff.speed[2]).toBe(true)
		expect(puff.size > 0).toBe(true)
		expect(puff.transparency >= 0).toBe(true)
		expect(puff.transparency < 1).toBe(true) -- a fully clear puff would be invisible
	end)
end)

describe("Config.Assets art pass images", function()
	local ART_KEYS = {
		"dustPuff",
		"coin",
		"bannerRibbon",
		"dailyCalendar",
	}

	it("has a valid ID for every slot the art pass draws", function()
		for _, key in ART_KEYS do
			expect(isAssetId(IMAGES[key])).toBe(true)
		end
	end)

	it("never points two slots at the same picture", function()
		-- Eight IDs pasted by hand in one go, as the menu tiles were: a copy and paste slip
		-- would put the wrong art in a slot and still look intentional.
		local seen = {}
		for _, key in ART_KEYS do
			local id = IMAGES[key]
			expect(seen[id]).toBe(nil)
			seen[id] = key
		end
	end)

	it("does not reuse art the game already had for something else", function()
		local existing = {
			IMAGES.play,
			IMAGES.leave,
			IMAGES.crown,
			IMAGES.player,
			IMAGES.stopwatch,
			IMAGES.confetti,
			IMAGES.logo,
		}
		for _, key in ART_KEYS do
			for _, id in existing do
				expect(IMAGES[key] == id).toBe(false)
			end
		end
	end)

	it("moved the confetti slot off the old single sparkle", function()
		-- The sheet and the sparkle are different pictures, and the readers of this slot
		-- now cut a cell out of it. Pointing it back at a single image would put a quarter
		-- of that image on screen.
		expect(isAssetId(IMAGES.confetti)).toBe(true)
		expect(IMAGES.confetti == 96276252812980).toBe(false)
	end)
end)
