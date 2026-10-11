--!strict
-- Arena dressing (D-07): a ring of lollipop props around the arena, in the palette colors.
-- Visual only: anchored, never collides, never blocks rays. Placeholder until the builder
-- delivers the real arena (slice 2). Lighting and effects are applied on each client instead
-- (LookController), since Lighting.ClockTime does not replicate.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)

local FOLDER_NAME = "ArenaProps"
-- The models Rojo maps into Workspace from models/ (slice 2 scenery).
local SCENERY_MODELS = { "Lobby", "SpectatorArea", "ArenaIsland", "CloudSea" }

local LookService = {}

local started = false

local function decorative(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = Config.Look.shadow.props
	part.Material = Enum.Material.SmoothPlastic
	part.Reflectance = Config.Look.tile.reflectance
end

-- Stops small scenery from casting shadows (phone pass). Roblox's own advice is to turn
-- CastShadow off on small and distant parts; here that is everything except the big island
-- meshes, whose shadow on the cloud sea is what makes the islands look like they float.
local function applySceneryShadows()
	local minSize = Config.Look.shadow.sceneryMinPartSize
	local cleared = 0
	for _, modelName in SCENERY_MODELS do
		local model = workspace:FindFirstChild(modelName)
		if model then
			for _, descendant in model:GetDescendants() do
				if descendant:IsA("BasePart") and descendant.CastShadow then
					local size = descendant.Size
					if math.max(size.X, size.Y, size.Z) < minSize then
						descendant.CastShadow = false
						cleared += 1
					end
				end
			end
		end
	end
	print(string.format("[Look] Shadow casting off on %d small scenery parts", cleared))
end

function LookService.start()
	assert(not started, "LookService.start() called twice")
	started = true

	local props = Config.Look.props
	local origin = Config.Arena.origin
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME

	local pillarHeight = props.pillarSize[2]
	-- The ball's top sits topBelowArena under the tiles, so props frame the arena without
	-- covering it from the players' cameras.
	local ballCenterY = origin[2] - props.topBelowArena - props.ballDiameter / 2
	local pillarCenterY = ballCenterY - pillarHeight / 2 -- the pillar top meets the ball centre

	for index = 1, props.count do
		local angle = (index - 1) / props.count * 2 * math.pi
		local x = origin[1] + math.cos(angle) * props.radius
		local z = origin[3] + math.sin(angle) * props.radius
		local colorDef = Config.Colors[(index - 1) % #Config.Colors + 1]
		local rgb = Util.hexToRgb(colorDef.hex)
		local color = Color3.fromRGB(rgb[1], rgb[2], rgb[3])

		local pillar = Instance.new("Part")
		pillar.Name = "Pillar" .. index
		pillar.Shape = Enum.PartType.Cylinder
		-- A cylinder's length runs along its X axis, so turn it upright.
		pillar.Size = Vector3.new(pillarHeight, props.pillarSize[1], props.pillarSize[3])
		pillar.CFrame = CFrame.new(x, pillarCenterY, z) * CFrame.Angles(0, 0, math.pi / 2)
		pillar.Color = color
		decorative(pillar)
		pillar.Parent = folder

		local ball = Instance.new("Part")
		ball.Name = "Ball" .. index
		ball.Shape = Enum.PartType.Ball
		ball.Size = Vector3.new(props.ballDiameter, props.ballDiameter, props.ballDiameter)
		ball.Position = Vector3.new(x, ballCenterY, z)
		ball.Color = color
		decorative(ball)
		ball.Parent = folder
	end

	folder.Parent = workspace
	print(string.format("[Look] Built %d arena props", props.count))

	applySceneryShadows()
end

return LookService
