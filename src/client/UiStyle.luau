--!strict
-- Shared look for the in-match UI (HUD, banners, lobby panel, eliminated card, spectate bar):
-- dark rounded panels, white text with a dark outline, and the fonts from Config.Hud.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local Sfx = require(script.Parent.Sfx)

local HUD = Config.Hud

local UiStyle = {}

local function toColor3(rgb: { number }): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local function hexColor(hex: string): Color3
	return toColor3(Util.hexToRgb(hex))
end

-- The Enum.Font called `name`, or the fallback font if there is none by that name.
local function fontNamed(name: string): Enum.Font
	for _, candidate in { name, HUD.fallbackFont } do
		local ok, font = pcall(function()
			return (Enum.Font :: any)[candidate]
		end)
		if ok and typeof(font) == "EnumItem" then
			return font :: any
		end
	end
	return Enum.Font.BuilderSansBold
end

local HEADING_FONT = fontNamed(HUD.headingFont)
local BODY_FONT = fontNamed(HUD.bodyFont)

local function assetUrl(id: number): string
	return "rbxassetid://" .. tostring(id)
end

local function addCorner(parent: GuiObject)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, HUD.cornerRadius)
	corner.Parent = parent
end

local function addPadding(parent: GuiObject)
	local padding = Instance.new("UIPadding")
	local pixels = UDim.new(0, HUD.padding)
	padding.PaddingTop = pixels
	padding.PaddingBottom = pixels
	padding.PaddingLeft = pixels
	padding.PaddingRight = pixels
	padding.Parent = parent
end

-- The white outline around a panel.
local function addPanelStroke(panel: GuiObject)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = toColor3(HUD.panelStrokeRgb)
	stroke.Thickness = HUD.panelStrokeThickness
	stroke.Parent = panel
end

local function makePanel(name: string, size: { number }, anchor: Vector2, position: UDim2): Frame
	local panel = Instance.new("Frame")
	panel.Name = name
	panel.AnchorPoint = anchor
	panel.Position = position
	panel.Size = UDim2.fromScale(size[1], size[2])
	panel.BackgroundColor3 = toColor3(HUD.panelRgb)
	panel.BackgroundTransparency = HUD.panelTransparency
	panel.BorderSizePixel = 0
	panel.Visible = false
	addCorner(panel)
	addPadding(panel)
	addPanelStroke(panel)
	return panel
end

-- White text with a dark outline, scaled to fit its box.
local function makeText(
	name: string,
	parent: Instance,
	font: Enum.Font,
	maxTextSize: number?
): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = font
	label.TextColor3 = toColor3(HUD.textRgb)
	label.TextScaled = true
	label.Text = ""
	label.Parent = parent

	local sizeLimit = Instance.new("UITextSizeConstraint")
	sizeLimit.MinTextSize = HUD.minTextSize
	sizeLimit.MaxTextSize = maxTextSize or HUD.maxTextSize
	sizeLimit.Parent = label

	local stroke = Instance.new("UIStroke")
	stroke.Color = toColor3(HUD.strokeRgb)
	stroke.Thickness = HUD.strokeThickness
	stroke.Parent = label
	return label
end

-- Motion (A-09) ----------------------------------------------------------------------------
-- Panels used to appear and disappear by flipping Visible, which made the results panel and
-- the eliminated card snap in. setShown gives them a short pop instead. It is safe to call
-- every frame, because only a change from the last call animates anything, and it falls back
-- to plain Visible when Config.Motion.enabled is false.

local MOTION = Config.Motion
local MOTION_SCALE_NAME = "MotionScale"

type ShowState = {
	scale: UIScale,
	tween: Tween?,
	shown: boolean,
}

-- Weak keys, so a destroyed panel does not keep its state alive.
local showStates: { [GuiObject]: ShowState } = setmetatable({}, { __mode = "k" }) :: any

-- The UIScale this module animates, created once per object. Panels that already have their
-- own UIScale (the banner and the timer) keep it: this one has its own name.
local function motionScale(object: GuiObject): UIScale
	local existing = object:FindFirstChild(MOTION_SCALE_NAME)
	if existing and existing:IsA("UIScale") then
		return existing
	end
	local scale = Instance.new("UIScale")
	scale.Name = MOTION_SCALE_NAME
	scale.Parent = object
	return scale
end

local function setShown(panel: GuiObject, shown: boolean)
	if not MOTION.enabled then
		panel.Visible = shown
		return
	end
	local state = showStates[panel]
	if not state then
		state = { scale = motionScale(panel), tween = nil, shown = panel.Visible }
		showStates[panel] = state
	end
	if state.shown == shown then
		return
	end
	state.shown = shown
	if state.tween then
		-- A panel shown and hidden quickly would otherwise have two tweens fighting.
		state.tween:Cancel()
		state.tween = nil
	end
	if shown then
		panel.Visible = true
		state.scale.Scale = MOTION.panelPopStartScale
		local info =
			TweenInfo.new(MOTION.panelPopSeconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		local tween = TweenService:Create(state.scale, info, { Scale = 1 })
		state.tween = tween
		tween.Completed:Connect(function()
			if state.shown then
				state.scale.Scale = 1
			end
		end)
		tween:Play()
	else
		local info =
			TweenInfo.new(MOTION.panelHideSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		local tween = TweenService:Create(state.scale, info, { Scale = MOTION.panelHideScale })
		state.tween = tween
		tween.Completed:Connect(function()
			-- Nothing showed it again while the tween ran, so it really is hidden now.
			if not state.shown then
				panel.Visible = false
				state.scale.Scale = 1
			end
		end)
		tween:Play()
	end
end

-- Whether a panel is logically shown. While a hide tween runs the panel is still Visible for
-- a fraction of a second, so code that toggles a panel asks this rather than reading Visible.
local function isShown(panel: GuiObject): boolean
	local state = showStates[panel]
	return if state then state.shown else panel.Visible
end

-- Shrinks a button while it is held. makeButton calls this, so every button in the game has
-- it; the scale returns to 1 on release and on the pointer leaving mid press.
local function pressFeedback(button: GuiButton)
	if not MOTION.enabled then
		return
	end
	local scale = motionScale(button)
	local info =
		TweenInfo.new(MOTION.buttonPressSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local function tweenTo(target: number)
		TweenService:Create(scale, info, { Scale = target }):Play()
	end
	button.MouseButton1Down:Connect(function()
		tweenTo(MOTION.buttonPressScale)
	end)
	button.MouseButton1Up:Connect(function()
		tweenTo(1)
	end)
	button.MouseLeave:Connect(function()
		tweenTo(1)
	end)
end

-- A rounded button with outlined text, in the HUD font. Clicks play the click sound.
local function makeButton(name: string, text: string, rgb: { number }): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Text = text
	button.Font = HEADING_FONT
	button.TextScaled = true
	button.TextColor3 = toColor3(HUD.textRgb)
	button.BackgroundColor3 = toColor3(rgb)
	button.BorderSizePixel = 0
	button.AutoButtonColor = true
	addCorner(button)
	addPadding(button)
	local sizeLimit = Instance.new("UITextSizeConstraint")
	sizeLimit.MinTextSize = HUD.minTextSize
	sizeLimit.MaxTextSize = HUD.maxTextSize
	sizeLimit.Parent = button
	-- Buttons are sized as a fraction of the screen, so on a phone they shrink with it. This
	-- keeps every one of them big enough to tap (Config.Touch).
	local touchSize = Instance.new("UISizeConstraint")
	local minPixels = Config.Touch.minButtonPixels
	touchSize.MinSize = Vector2.new(minPixels, minPixels)
	touchSize.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Color = toColor3(HUD.strokeRgb)
	stroke.Thickness = HUD.strokeThickness
	stroke.Parent = button
	pressFeedback(button)
	button.Activated:Connect(function()
		Sfx.play("click")
	end)
	return button
end

UiStyle.makeButton = makeButton
UiStyle.toColor3 = toColor3
UiStyle.hexColor = hexColor
UiStyle.fontNamed = fontNamed
UiStyle.HEADING_FONT = HEADING_FONT
UiStyle.BODY_FONT = BODY_FONT
UiStyle.assetUrl = assetUrl
UiStyle.addCorner = addCorner
UiStyle.addPadding = addPadding
UiStyle.makePanel = makePanel
UiStyle.addPanelStroke = addPanelStroke
UiStyle.makeText = makeText
UiStyle.setShown = setShown
UiStyle.isShown = isShown
UiStyle.pressFeedback = pressFeedback

return UiStyle
