--!strict
-- The loading screen (A-01).
--
-- This runs from ReplicatedFirst, which is the only place early enough to replace Roblox's
-- default loading screen. Everything else the client does lives in StarterPlayerScripts,
-- which does not run until the default screen has already gone.
--
-- While it is up it preloads the assets in Config.Assets. Before this, each asset loaded at
-- the moment it was first needed, which is what produced the "[HUD] Image did not load"
-- warnings in D-06: the HUD asked for art the client had not fetched yet.
--
-- The decisions (progress, tips, when it may close) are in shared/LoadingModel, which is
-- pure and tested. This file is the drawing and the waiting.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

-- Take the default screen over straight away, before anything is drawn. If this script
-- errored after this point the player would see a bare viewport, so what follows is
-- deliberately simple and has no failure path that leaves the screen up.
ReplicatedFirst:RemoveDefaultLoadingScreen()

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ReplicatedFirst runs before the rest of ReplicatedStorage has arrived, so this waits.
-- It is normally a few frames. Config holds every number on this screen, so there is
-- nothing sensible to draw until it is here.
local shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(shared:WaitForChild("Config"))

local LOADING = Config.Loading
local ASSETS = Config.Assets

local LoadingModel = require(shared:WaitForChild("LoadingModel"))

local function toColor3(rgb: { number }): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local function assetUrl(id: number): string
	return "rbxassetid://" .. tostring(id)
end

-- Building the screen ------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "LoadingScreen"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 1000 -- above everything, including the menu overlay
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local backdrop = Instance.new("Frame")
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = toColor3(LOADING.backdropRgb)
backdrop.BorderSizePixel = 0
backdrop.Parent = gui

-- The key art, when it has been uploaded. Until then the backdrop and logo carry the
-- screen on their own, so this works with Config.Assets.Images.loadingArt still at 0.
if ASSETS.Images.loadingArt ~= 0 then
	local art = Instance.new("ImageLabel")
	art.Size = UDim2.fromScale(1, 1)
	art.BackgroundTransparency = 1
	art.Image = assetUrl(ASSETS.Images.loadingArt)
	-- Crop rather than stretch: the art is a fixed shape and phones are not.
	art.ScaleType = Enum.ScaleType.Crop
	art.Parent = backdrop
else
	local logo = Instance.new("ImageLabel")
	logo.AnchorPoint = Vector2.new(0.5, 0)
	logo.Position = UDim2.fromScale(0.5, LOADING.logoY)
	logo.Size = UDim2.fromScale(LOADING.logoSize[1], LOADING.logoSize[2])
	logo.BackgroundTransparency = 1
	logo.Image = assetUrl(ASSETS.Images.logo)
	logo.ScaleType = Enum.ScaleType.Fit
	logo.Parent = backdrop
end

local track = Instance.new("Frame")
track.AnchorPoint = Vector2.new(0.5, 0.5)
track.Position = UDim2.fromScale(0.5, LOADING.barY)
track.Size = UDim2.fromScale(LOADING.barWidth, LOADING.barHeight)
track.BackgroundColor3 = toColor3(LOADING.barTrackRgb)
track.BackgroundTransparency = LOADING.barTrackTransparency
track.BorderSizePixel = 0
track.Parent = backdrop

local trackCorner = Instance.new("UICorner")
trackCorner.CornerRadius = UDim.new(1, 0)
trackCorner.Parent = track

local fill = Instance.new("Frame")
fill.Size = UDim2.fromScale(0, 1)
fill.BackgroundColor3 = toColor3(LOADING.barRgb)
fill.BorderSizePixel = 0
fill.Parent = track

local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(1, 0)
fillCorner.Parent = fill

local function label(y: number, scale: number): TextLabel
	local text = Instance.new("TextLabel")
	text.AnchorPoint = Vector2.new(0.5, 0.5)
	text.Position = UDim2.fromScale(0.5, y)
	text.Size = UDim2.fromScale(0.8, 0.06)
	text.BackgroundTransparency = 1
	text.TextColor3 = toColor3(LOADING.textRgb)
	text.TextStrokeTransparency = 0.4
	text.TextScaled = true
	text.Font = Enum.Font.BuilderSansBold
	text.Text = ""
	text.Parent = backdrop

	local constraint = Instance.new("UITextSizeConstraint")
	constraint.MaxTextSize = math.floor(scale)
	constraint.Parent = text
	return text
end

local percentLabel = label(LOADING.barY + 0.06, 28)
local tipLabel = label(LOADING.barY + 0.13, 22)

-- Preloading ---------------------------------------------------------------------------

-- Every asset id in Config.Assets, flattened. Walks the table rather than listing them,
-- so an asset added to Config by a later task is preloaded without touching this file.
local function collectAssets(): { string }
	local urls = {}
	local seen = {}
	local function walk(value: any)
		if type(value) == "number" then
			if value ~= 0 and not seen[value] then
				seen[value] = true
				table.insert(urls, assetUrl(value))
			end
		elseif type(value) == "table" then
			for _, child in value do
				walk(child)
			end
		end
	end
	walk(ASSETS)
	return urls
end

local urls = collectAssets()
local total = #urls
local done = 0
local preloadFinished = false

task.spawn(function()
	-- PreloadAsync yields until the whole list is handled, calling back per asset.
	local ok, err = pcall(function()
		ContentProvider:PreloadAsync(urls, function()
			done += 1
		end)
	end)
	if not ok then
		warn(string.format("[Loading] preload failed: %s", tostring(err)))
	end
	preloadFinished = true
end)

-- Waiting and closing --------------------------------------------------------------------

local started = os.clock()

while true do
	local elapsed = os.clock() - started

	fill.Size = UDim2.fromScale(LoadingModel.progress(done, total), 1)
	percentLabel.Text = LoadingModel.percentText(done, total)
	tipLabel.Text = LoadingModel.tipAt(elapsed, LOADING.tipSeconds)

	-- A single asset that never resolves must not hold the player here for ever. When the
	-- deadline passes, the rest keeps loading in the background and the player goes in.
	if
		not preloadFinished and LoadingModel.preloadTimedOut(elapsed, LOADING.preloadTimeoutSeconds)
	then
		warn(
			string.format(
				"[Loading] preload still running after %d seconds, continuing without it (%d of %d)",
				LOADING.preloadTimeoutSeconds,
				done,
				total
			)
		)
		preloadFinished = true
	end

	if LoadingModel.canClose(game:IsLoaded(), preloadFinished, elapsed, LOADING.minSeconds) then
		break
	end
	task.wait()
end

print(
	string.format("[Loading] ready after %.1fs, %d of %d assets", os.clock() - started, done, total)
)

local fade = TweenInfo.new(LOADING.fadeSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
for _, item in backdrop:GetDescendants() do
	if item:IsA("ImageLabel") then
		TweenService:Create(item, fade, { ImageTransparency = 1 }):Play()
	elseif item:IsA("TextLabel") then
		TweenService:Create(item, fade, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	elseif item:IsA("Frame") then
		TweenService:Create(item, fade, { BackgroundTransparency = 1 }):Play()
	end
end
TweenService:Create(backdrop, fade, { BackgroundTransparency = 1 }):Play()

task.wait(LOADING.fadeSeconds)
gui:Destroy()
