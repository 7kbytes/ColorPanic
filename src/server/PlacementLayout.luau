--!strict
-- Pure placement helpers. No side effects and no world state, so they can be unit tested.

local PlacementLayout = {}

-- Returns `count` tile indices in 1..tileCount, in random order. Indices are distinct while
-- count <= tileCount; beyond that the shuffled order repeats so every player still gets a tile.
function PlacementLayout.pickTileIndices(tileCount: number, count: number, rng: Random): { number }
	assert(tileCount > 0, "PlacementLayout.pickTileIndices needs at least one tile")

	local order: { number } = table.create(tileCount)
	for i = 1, tileCount do
		order[i] = i
	end
	for i = tileCount, 2, -1 do
		local j = rng:NextInteger(1, i)
		order[i], order[j] = order[j], order[i]
	end

	local picked: { number } = table.create(count)
	for i = 1, count do
		picked[i] = order[((i - 1) % tileCount) + 1]
	end
	return picked
end

-- Returns spawn offsets on a grid centered on the origin, `columns` wide, `spacing` apart.
-- Each offset is { x, z } in studs.
function PlacementLayout.gridOffsets(
	count: number,
	columns: number,
	spacing: number
): { { number } }
	local rows = math.ceil(count / columns)
	local offsets: { { number } } = table.create(count)
	for i = 1, count do
		local column = (i - 1) % columns
		local row = (i - 1) // columns
		offsets[i] = {
			(column - (columns - 1) / 2) * spacing,
			(row - (rows - 1) / 2) * spacing,
		}
	end
	return offsets
end

return PlacementLayout
