--!strict
-- Which scenery props stop a player, and the shape of the collider that does it.
--
-- The 3D models keep their meshes in a Visuals folder with CanCollide off, and put the
-- collision on cheap invisible primitives in a Collision folder. Mesh collision on a palm
-- tree would cost phone performance and give a lumpy hull that blocks the fronds as well as
-- the trunk, so props get primitives too. This module decides the primitives; PropCollision
-- builds them.
--
-- Pure, so it is tested outside Studio. Sizes are plain numbers, like the other layout
-- modules, rather than Vector3.

local Types = require(script.Parent.Types)

type PropRule = Types.PropRule

local CollisionRules = {}

-- One invisible part to build, in studs, relative to the prop's own centre.
export type Collider = {
	kind: "box" | "cylinder", -- a cylinder stands upright, like the lobby floor disc
	width: number, -- X
	height: number, -- Y
	depth: number, -- Z
	offsetX: number,
	offsetZ: number,
}

-- The colliders for one prop, given the size of its mesh.
--
-- `rules` is Config.Props. A prop with no rule gets nothing and stays walk-through, which
-- is deliberate for ground scatter: colliding with ankle height rocks reads as getting
-- stuck rather than as solidity.
function CollisionRules.collidersFor(
	propName: string,
	sizeX: number,
	sizeY: number,
	sizeZ: number,
	rules: { [string]: PropRule }
): { Collider }
	local rule = rules[propName]
	if not rule or sizeY <= 0 then
		return {}
	end

	if rule.kind == "cylinder" then
		-- A post or a trunk: a narrow upright cylinder on the prop's centre line, so the
		-- wide parts above it (fronds, a lamp head) stay clear.
		local diameter = math.min(rule.radius * 2, math.min(sizeX, sizeZ))
		return {
			{
				kind = "cylinder",
				width = diameter,
				height = sizeY,
				depth = diameter,
				offsetX = 0,
				offsetZ = 0,
			},
		}
	elseif rule.kind == "posts" then
		-- An arch: one post down each side, leaving the walkway between them open.
		local postWidth = math.min(rule.postWidth, sizeX / 2)
		local inset = sizeX / 2 - postWidth / 2
		local depth = math.min(rule.postDepth, sizeZ)
		local posts = {}
		for _, side in { -1, 1 } do
			table.insert(posts, {
				kind = "box" :: "box",
				width = postWidth,
				height = sizeY,
				depth = depth,
				offsetX = inset * side,
				offsetZ = 0,
			})
		end
		return posts
	end

	-- A solid block: the whole footprint, pulled in slightly so a player brushing past the
	-- edge is not stopped by a collider wider than the thing they can see.
	local inset = rule.inset
	return {
		{
			kind = "box",
			width = math.max(sizeX - inset * 2, inset),
			height = sizeY,
			depth = math.max(sizeZ - inset * 2, inset),
			offsetX = 0,
			offsetZ = 0,
		},
	}
end

-- Whether this prop is left walk-through.
function CollisionRules.isWalkThrough(propName: string, rules: { [string]: PropRule }): boolean
	return rules[propName] == nil
end

return CollisionRules
