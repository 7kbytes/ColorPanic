--!strict
-- Pure tile layout generation. No side effects and no world state, so it can be unit tested.

local Types = require(game:GetService("ReplicatedStorage").Shared.Types)

type ColorId = Types.ColorId

-- Ensures at least minCount tiles of colorId. RoundDirector (S1-06) supplies the numbers.
export type Guarantee = {
	colorId: ColorId,
	minCount: number,
}

local ArenaLayout = {}

-- Returns one color id per tile. Colors are spread as evenly as possible, the guarantee
-- is applied, then the list is shuffled with rng.
function ArenaLayout.generate(
	tileCount: number,
	colorIds: { ColorId },
	rng: Random,
	guarantee: Guarantee?
): { ColorId }
	assert(#colorIds > 0, "ArenaLayout.generate needs at least one color")

	local layout: { ColorId } = table.create(tileCount)
	for i = 1, tileCount do
		layout[i] = colorIds[((i - 1) % #colorIds) + 1]
	end

	if guarantee then
		local needed = math.min(guarantee.minCount, tileCount)
		for _, colorId in layout do
			if colorId == guarantee.colorId then
				needed -= 1
			end
		end
		local i = 1
		while needed > 0 and i <= tileCount do
			if layout[i] ~= guarantee.colorId then
				layout[i] = guarantee.colorId
				needed -= 1
			end
			i += 1
		end
	end

	-- Fisher-Yates shuffle
	for i = tileCount, 2, -1 do
		local j = rng:NextInteger(1, i)
		layout[i], layout[j] = layout[j], layout[i]
	end

	return layout
end

return ArenaLayout
