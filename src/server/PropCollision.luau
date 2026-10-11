--!strict
-- Makes scenery props solid (A-03).
--
-- The 3D models put every mesh in a Visuals folder with CanCollide off, and keep collision
-- on invisible primitives in a Collision folder: a floor disc, railings, the platform. The
-- props never got that treatment, so players walked through the palms, lamps, pillars and
-- the arch.
--
-- This adds the missing primitives at startup, from each prop mesh's real position and
-- size, rather than editing the model files. CollisionRules decides the shapes and is
-- tested; this places them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CollisionRules = require(ReplicatedStorage.Shared.CollisionRules)
local Config = require(ReplicatedStorage.Shared.Config)

local PropCollision = {}

local started = false

-- Builds one invisible collider for `prop`, in the model's Collision folder.
--
-- Parented to the Collision folder rather than to the prop so the models keep their
-- shape: everything collidable in one place, everything visible in the other.
local function buildCollider(
	prop: BasePart,
	collider: CollisionRules.Collider,
	index: number,
	parent: Instance
)
	local part = Instance.new("Part")
	part.Name = string.format("%sCollider%d", prop.Name, index)
	part.Anchored = true
	part.Transparency = 1
	part.CastShadow = false
	part.CanTouch = false
	part.CanQuery = false
	part.CanCollide = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth

	-- The prop's own rotation, so a collider on a turned prop turns with it. The offset is
	-- applied in the prop's frame for the same reason.
	local base = prop.CFrame * CFrame.new(collider.offsetX, 0, collider.offsetZ)

	if collider.kind == "cylinder" then
		-- Roblox cylinders lie along X, so an upright one is sized (height, d, d) and
		-- turned a quarter turn, the same way the lobby floor disc is built.
		part.Shape = Enum.PartType.Cylinder
		part.Size = Vector3.new(collider.height, collider.width, collider.depth)
		part.CFrame = base * CFrame.Angles(0, 0, math.rad(90))
	else
		part.Size = Vector3.new(collider.width, collider.height, collider.depth)
		part.CFrame = base
	end

	part.Parent = parent
end

-- Adds colliders for every prop in one model, and returns how many it added.
local function solidify(model: Instance): number
	local visuals = model:FindFirstChild("Visuals")
	local collision = model:FindFirstChild("Collision")
	if not visuals or not collision then
		return 0 -- not a model built by the assembly scripts
	end

	local added = 0
	for _, prop in visuals:GetChildren() do
		if not prop:IsA("BasePart") then
			continue
		end
		local colliders = CollisionRules.collidersFor(
			prop.Name,
			prop.Size.X,
			prop.Size.Y,
			prop.Size.Z,
			Config.Props
		)
		for index, collider in colliders do
			buildCollider(prop, collider, index, collision)
			added += 1
		end
	end
	return added
end

function PropCollision.start()
	assert(not started, "PropCollision.start() called twice")
	started = true

	local total = 0
	local models = {}
	for _, model in workspace:GetChildren() do
		local count = solidify(model)
		if count > 0 then
			total += count
			table.insert(models, string.format("%s %d", model.Name, count))
		end
	end

	if total == 0 then
		-- Not an error: a place synced without the models still plays.
		print("[Props] no scenery props to make solid")
	else
		print(string.format("[Props] %d colliders added (%s)", total, table.concat(models, ", ")))
	end
end

return PropCollision
