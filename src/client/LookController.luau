--!strict
-- Arena look on this client (D-07): soft lighting, a hazy bright sky, subtle bloom and color
-- correction, and a confetti burst at Victory. Visual only. Applied on the client because
-- Lighting.ClockTime does not replicate from the server.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Util = require(ReplicatedStorage.Shared.Util)
local UiStyle = require(script.Parent.UiStyle)

local LOOK = Config.Look
local toColor3 = UiStyle.toColor3
-- Above the HUD and spectate UI, under the menu.
local CONFETTI_DISPLAY_ORDER = 6

local LookController = {}

local started = false

-- Replaces any effect of the same class we made before, so a restart never stacks them.
local function effect<T>(className: string, parent: Instance): T
	local name = "ColorPanic" .. className
	local existing = parent:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
	local instance = Instance.new(className :: any)
	instance.Name = name
	instance.Parent = parent
	return instance :: any
end

local function applyLighting()
	local lighting = LOOK.lighting
	Lighting.ClockTime = lighting.clockTime
	Lighting.Brightness = lighting.brightness
	Lighting.Ambient = toColor3(lighting.ambientRgb)
	Lighting.OutdoorAmbient = toColor3(lighting.outdoorAmbientRgb)
	Lighting.EnvironmentDiffuseScale = lighting.environmentDiffuseScale
	Lighting.EnvironmentSpecularScale = lighting.environmentSpecularScale
	Lighting.ExposureCompensation = lighting.exposureCompensation
	Lighting.GlobalShadows = true

	local atmosphere = effect("Atmosphere", Lighting) :: Atmosphere
	atmosphere.Density = LOOK.atmosphere.density
	atmosphere.Offset = LOOK.atmosphere.offset
	atmosphere.Haze = LOOK.atmosphere.haze
	atmosphere.Glare = LOOK.atmosphere.glare
	atmosphere.Color = toColor3(LOOK.atmosphere.colorRgb)
	atmosphere.Decay = toColor3(LOOK.atmosphere.decayRgb)

	local bloom = effect("BloomEffect", Lighting) :: BloomEffect
	bloom.Intensity = LOOK.bloom.intensity
	bloom.Size = LOOK.bloom.size
	bloom.Threshold = LOOK.bloom.threshold

	local correction = effect("ColorCorrectionEffect", Lighting) :: ColorCorrectionEffect
	correction.Saturation = LOOK.colorCorrection.saturation
	correction.Contrast = LOOK.colorCorrection.contrast
	correction.Brightness = LOOK.colorCorrection.brightness
end

-- A burst of confetti pieces falling across the screen, in the palette colors.
local function burstConfetti(screenGui: ScreenGui)
	local id = Config.Assets.Images.confetti
	if id == 0 then
		return
	end
	local confetti = LOOK.confetti
	local random = Random.new()
	for index = 1, confetti.pieces do
		local colorDef = Config.Colors[(index - 1) % #Config.Colors + 1]
		local piece = Instance.new("ImageLabel")
		piece.Name = "Confetti"
		piece.BackgroundTransparency = 1
		piece.Image = UiStyle.assetUrl(id)
		piece.ImageColor3 = toColor3(Util.hexToRgb(colorDef.hex))
		piece.AnchorPoint = Vector2.new(0.5, 0.5)
		piece.Size = UDim2.fromOffset(confetti.sizePixels, confetti.sizePixels)
		piece.Position = UDim2.fromScale(random:NextNumber(), random:NextNumber(-0.3, 0))
		piece.Rotation = random:NextNumber(0, 360)
		piece.Parent = screenGui
		local seconds = confetti.seconds * random:NextNumber(0.7, 1.1)
		local fall = TweenService:Create(piece, TweenInfo.new(seconds, Enum.EasingStyle.Linear), {
			Position = UDim2.fromScale(
				piece.Position.X.Scale + random:NextNumber(-0.15, 0.15),
				1.1
			),
			Rotation = piece.Rotation + random:NextNumber(180, 720),
			ImageTransparency = 0.3,
		})
		fall.Completed:Connect(function()
			piece:Destroy()
		end)
		fall:Play()
	end
end

function LookController.start()
	assert(not started, "LookController.start() called twice")
	started = true

	applyLighting()

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "Confetti"
	screenGui.ResetOnSpawn = false
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = CONFETTI_DISPLAY_ORDER
	screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	Remotes.StateChanged.connect(function(payload)
		if payload.state == "Victory" then
			burstConfetti(screenGui)
		end
	end)
end

return LookController
