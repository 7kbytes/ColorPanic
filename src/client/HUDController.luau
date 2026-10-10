--!strict
-- Placeholder HUD: plain text for state, round, target color, timer and players left.
-- During Victory the state line names the winners.
-- Driven only by server remotes; the timer counts down to the server's endsAt.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local HudModel = require(script.Parent.HudModel)

-- Top to bottom order of the lines on screen.
local LINE_ORDER = { "state", "round", "target", "timer", "playersLeft" }

local HUDController = {}

local started = false

local function toColor3(rgb: { number }): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local hudGui: ScreenGui? = nil

local function buildGui(): { [string]: TextLabel }
	local hud = Config.Hud
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "HUD"
	-- Keep the HUD when the character respawns after falling.
	screenGui.ResetOnSpawn = false
	-- Stay inside the device safe area (notches, top bar).
	screenGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets

	-- Top centre, clear of the thumbstick and jump button at the bottom corners.
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.fromScale(0.5, hud.topMargin)
	panel.Size = UDim2.fromScale(hud.width, hud.height)
	panel.BackgroundColor3 = toColor3(hud.backgroundRgb)
	panel.BackgroundTransparency = hud.backgroundTransparency
	panel.BorderSizePixel = 0
	panel.Parent = screenGui

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, hud.padding)
	padding.PaddingBottom = UDim.new(0, hud.padding)
	padding.PaddingLeft = UDim.new(0, hud.padding)
	padding.PaddingRight = UDim.new(0, hud.padding)
	padding.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = panel

	local labels: { [string]: TextLabel } = {}
	for index, key in LINE_ORDER do
		local label = Instance.new("TextLabel")
		label.Name = key
		label.LayoutOrder = index
		label.Size = UDim2.fromScale(1, 1 / #LINE_ORDER)
		label.BackgroundTransparency = 1
		label.TextColor3 = toColor3(hud.textRgb)
		label.TextScaled = true
		label.Font = Enum.Font.BuilderSansBold
		label.Text = ""
		label.Parent = panel

		local sizeLimit = Instance.new("UITextSizeConstraint")
		sizeLimit.MinTextSize = hud.minTextSize
		sizeLimit.MaxTextSize = hud.maxTextSize
		sizeLimit.Parent = label

		labels[key] = label
	end

	screenGui.Parent = playerGui
	hudGui = screenGui
	return labels
end

-- Shows or hides the whole HUD (hidden while the menu is up).
function HUDController.setVisible(visible: boolean)
	if hudGui then
		hudGui.Enabled = visible
	end
end

function HUDController.start()
	assert(not started, "HUDController.start() called twice")
	started = true

	local labels = buildGui()
	local model = HudModel.new()

	local function render()
		local lines = HudModel.lines(model, workspace:GetServerTimeNow()) :: { [string]: string }
		for key, label in labels do
			local text = lines[key]
			if label.Text ~= text then
				label.Text = text
			end
		end
	end

	Remotes.StateChanged.connect(function(payload)
		HudModel.applyState(model, payload)
		render()
	end)
	Remotes.RoundInfo.connect(function(payload)
		HudModel.applyRoundInfo(model, payload)
		render()
	end)
	Remotes.TargetAnnounced.connect(function(payload)
		HudModel.applyTarget(model, payload)
		render()
	end)
	Remotes.PlayerEliminated.connect(function(payload)
		HudModel.applyEliminated(model, payload)
		render()
	end)
	Remotes.MatchResult.connect(function(payload)
		HudModel.applyMatchResult(model, payload)
		render()
	end)

	-- Only the timer changes between remotes; render() skips labels whose text is unchanged.
	RunService.Heartbeat:Connect(render)
	render()
end

return HUDController
