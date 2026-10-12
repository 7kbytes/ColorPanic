--!strict
-- The win celebration (A-09): confetti over the winner and a short camera punch when the
-- results panel says the local player won. Runs on the winner's own client only, and clears
-- itself up afterwards, so nothing is left behind for the next match.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)

local WIN = Config.Motion.Win
local ATTACHMENT_NAME = "WinConfetti"

local WinFx = {}

-- Confetti in the game's own palette, so it matches the tiles rather than introducing colors.
local function confettiColors(): ColorSequence
	local keypoints: { ColorSequenceKeypoint } = {}
	local count = #Config.Colors
	for index, colorDef in Config.Colors do
		local rgb = Util.hexToRgb(colorDef.hex)
		local time = if count > 1 then (index - 1) / (count - 1) else 0
		table.insert(
			keypoints,
			ColorSequenceKeypoint.new(time, Color3.fromRGB(rgb[1], rgb[2], rgb[3]))
		)
	end
	return ColorSequence.new(keypoints)
end

local palette = confettiColors()

-- True while a celebration is running, so a re-render cannot stack two of them.
local running = false

local function burstConfetti()
	local character = Players.LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not root or not root:IsA("BasePart") then
		return
	end
	-- An old attachment can survive a very fast second win; the name makes it easy to find.
	local previous = root:FindFirstChild(ATTACHMENT_NAME)
	if previous then
		previous:Destroy()
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = ATTACHMENT_NAME
	attachment.Position = Vector3.new(0, WIN.confettiHeight, 0)
	attachment.Parent = root

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = palette
	emitter.Rate = WIN.confettiRate
	emitter.Lifetime = NumberRange.new(WIN.confettiLifetime[1], WIN.confettiLifetime[2])
	emitter.Speed = NumberRange.new(WIN.confettiSpeed[1], WIN.confettiSpeed[2])
	emitter.Size = NumberSequence.new(WIN.confettiSize)
	emitter.SpreadAngle = Vector2.new(WIN.confettiSpread, WIN.confettiSpread)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.RotSpeed = NumberRange.new(-180, 180)
	emitter.Parent = attachment

	task.delay(WIN.confettiSeconds, function()
		emitter.Enabled = false
		-- Let the particles already in the air finish their lifetime before the attachment
		-- goes, otherwise they vanish mid flight.
		task.delay(WIN.confettiLifetime[2], function()
			if attachment.Parent then
				attachment:Destroy()
			end
		end)
	end)
end

local function punchCamera()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local base = camera.FieldOfView
	local out = TweenInfo.new(WIN.fovOutSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local back = TweenInfo.new(WIN.fovBackSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local punch = TweenService:Create(camera, out, { FieldOfView = base + WIN.fovDelta })
	punch.Completed:Connect(function()
		-- Always tween back to the value we found, so an interrupted punch cannot leave the
		-- camera zoomed for the rest of the session.
		TweenService:Create(camera, back, { FieldOfView = base }):Play()
	end)
	punch:Play()
end

-- Celebrates a win. Safe to call repeatedly: it does nothing while one is already running.
function WinFx.celebrate()
	if not Config.Motion.enabled or running then
		return
	end
	running = true
	burstConfetti()
	punchCamera()
	task.delay(WIN.confettiSeconds + WIN.confettiLifetime[2], function()
		running = false
	end)
end

return WinFx
