--!strict
-- Shared look for the in-match UI (HUD, banners, lobby panel, eliminated card, spectate bar):
-- dark rounded panels, white text with a dark outline, and the fonts from Config.Hud.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)

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

-- A rounded button with outlined text, in the HUD font.
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
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Color = toColor3(HUD.strokeRgb)
	stroke.Thickness = HUD.strokeThickness
	stroke.Parent = button
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
UiStyle.makeText = makeText

return UiStyle
