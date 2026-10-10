--!strict
-- In-match HUD (D-06): the target card at the top centre with the round badge on its left and
-- players left on its right, a status line under it and a timer bar at the bottom centre. The
-- corners stay free for Roblox's chat and player list and the touch thumbstick and jump button.
-- Draws HudModel.view only; every value comes from server remotes. Icons that are not uploaded
-- (ID 0) or fail to load fall back to text, so the HUD never shows an empty box.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local BannerModel = require(script.Parent.BannerModel)
local HudModel = require(script.Parent.HudModel)
local LobbyModel = require(script.Parent.LobbyModel)
local ResultsModel = require(script.Parent.ResultsModel)
local UiStyle = require(script.Parent.UiStyle)

type ShapeId = Types.ShapeId

local HUD = Config.Hud

local HUDController = {}

local started = false
local hudGui: ScreenGui? = nil

local toColor3 = UiStyle.toColor3
local hexColor = UiStyle.hexColor
local HEADING_FONT = UiStyle.HEADING_FONT
local BODY_FONT = UiStyle.BODY_FONT
local assetUrl = UiStyle.assetUrl
local addCorner = UiStyle.addCorner
local addPadding = UiStyle.addPadding
local makePanel = UiStyle.makePanel
local makeText = UiStyle.makeText

-- One image an icon can show, tinted with `tint` (UNTINTED leaves the art as drawn).
type IconChoice = { id: number, tint: Color3 }

-- A square icon slot on the left of a panel. It shows the first of its choices that has an ID
-- and has not failed to load, or the fallback text when none is left.
type Icon = {
	slot: Frame,
	image: ImageLabel,
	fallback: TextLabel,
	choices: { IconChoice },
	fallbackText: string,
	failedUrls: { [string]: boolean },
	failed: boolean, -- showing the fallback text
}

local UNTINTED = toColor3(HUD.untintedRgb)

local function makeIcon(parent: Instance, widthScale: number): Icon
	local slot = Instance.new("Frame")
	slot.Name = "Icon"
	slot.BackgroundTransparency = 1
	slot.Size = UDim2.fromScale(widthScale, 1)
	slot.Parent = parent
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = 1
	aspect.Parent = slot

	local image = Instance.new("ImageLabel")
	image.Name = "Image"
	image.BackgroundTransparency = 1
	image.Size = UDim2.fromScale(1, 1)
	image.ScaleType = Enum.ScaleType.Fit
	image.ZIndex = 2 -- above a swatch behind it
	image.Parent = slot

	local fallback = makeText("Fallback", slot, HEADING_FONT)
	fallback.ZIndex = 3
	fallback.Visible = false
	return {
		slot = slot,
		image = image,
		fallback = fallback,
		choices = {},
		fallbackText = "",
		failedUrls = {},
		failed = false,
	}
end

-- Shows the icon's first usable choice. A choice that fails to load is marked failed, and the
-- icon moves on to the next one.
local function showIcon(icon: Icon)
	for _, choice in icon.choices do
		local url = if choice.id ~= 0 then assetUrl(choice.id) else nil
		if url and not icon.failedUrls[url] then
			icon.failed = false
			icon.image.ImageColor3 = choice.tint
			if icon.image.Image ~= url then
				icon.image.Image = url
				-- Preload the ImageLabel itself: preloading the bare asset ID string reported
				-- failures for images that load fine (seen in Studio QA).
				task.spawn(function()
					ContentProvider:PreloadAsync({ icon.image }, function(contentId, status)
						local failedNow = status ~= Enum.AssetFetchStatus.Success
							and contentId == url
							and not icon.failedUrls[url]
						if failedNow then
							icon.failedUrls[url] = true
							warn(
								string.format(
									"[HUD] Image %s did not load (%s)",
									url,
									tostring(status)
								)
							)
							showIcon(icon)
						end
					end)
				end)
			end
			icon.image.Visible = true
			icon.fallback.Visible = false
			return
		end
	end
	icon.failed = true
	icon.fallback.Text = icon.fallbackText
	icon.image.Visible = false
	icon.fallback.Visible = true
end

local function setIcon(icon: Icon, choices: { IconChoice }, fallbackText: string)
	icon.choices = choices
	icon.fallbackText = fallbackText
	showIcon(icon)
end

-- A panel with an icon on the left and a body filling the rest, holding a text label.
local function makeBadge(
	name: string,
	size: { number },
	anchor: Vector2,
	position: UDim2,
	parent: Instance
)
	local panel = makePanel(name, size, anchor, position)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, HUD.padding)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = panel
	local icon = makeIcon(panel, 0.3)
	icon.slot.LayoutOrder = 1
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.LayoutOrder = 2
	body.Size = UDim2.fromScale(1, 1)
	body.Parent = panel
	local flex = Instance.new("UIFlexItem")
	flex.FlexMode = Enum.UIFlexMode.Fill
	flex.Parent = body
	local text = makeText("Text", body, HEADING_FONT)
	text.ZIndex = 2 -- above a timer track in the same body
	panel.Parent = parent
	return panel, icon, body, text
end

type ResultRow = { frame: Frame, place: TextLabel, name: TextLabel, detail: TextLabel }

type Widgets = {
	roundPanel: Frame,
	roundText: TextLabel,
	playersPanel: Frame,
	playersText: TextLabel,
	targetPanel: Frame,
	targetIcon: Icon,
	targetSwatch: Frame,
	targetName: TextLabel,
	status: TextLabel,
	timerPanel: Frame,
	timerScale: UIScale,
	timerFill: Frame,
	timerText: TextLabel,
	banner: Frame,
	bannerScale: UIScale,
	bannerTitle: TextLabel,
	bannerSubtitle: TextLabel,
	lobbyPanel: Frame,
	lobbyTitle: TextLabel,
	lobbyCount: TextLabel,
	lobbyStatus: TextLabel,
	results: Frame,
	resultsTitle: TextLabel,
	resultsSubtitle: TextLabel,
	resultsRows: { ResultRow },
	resultsMore: TextLabel,
}

local function buildGui(): Widgets
	local margin = HUD.margin
	-- The badges hug the target card's sides.
	local cardHalf = HUD.targetCardSize[1] / 2
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "HUD"
	-- Keep the HUD when the character respawns after falling.
	screenGui.ResetOnSpawn = false
	-- Stay inside the device safe area (notches, the Roblox top bar).
	screenGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets

	local roundPanel, roundIcon, _, roundText = makeBadge(
		"RoundBadge",
		HUD.roundBadgeSize,
		Vector2.new(1, 0),
		UDim2.fromScale(0.5 - cardHalf - HUD.gap, margin),
		screenGui
	)
	-- The badge text already says "Round", so a missing crown needs no stand-in.
	setIcon(roundIcon, { { id = Config.Assets.Images.crown, tint = UNTINTED } }, "")

	local playersPanel, playersIcon, _, playersText = makeBadge(
		"PlayersBadge",
		HUD.playersBadgeSize,
		Vector2.new(0, 0),
		UDim2.fromScale(0.5 + cardHalf + HUD.gap, margin),
		screenGui
	)
	setIcon(playersIcon, { { id = Config.Assets.Images.player, tint = UNTINTED } }, "Left")

	-- Target card: the target's tile art (as drawn on the arena), then the color name. If the
	-- tile art is missing it falls back to the white shape icon tinted with the color, then to
	-- a swatch of the color with the shape name.
	local targetPanel, targetIcon, _, targetName = makeBadge(
		"TargetCard",
		HUD.targetCardSize,
		Vector2.new(0.5, 0),
		UDim2.fromScale(0.5, margin),
		screenGui
	)
	local targetSwatch = Instance.new("Frame")
	targetSwatch.Name = "Swatch"
	targetSwatch.BorderSizePixel = 0
	targetSwatch.Size = UDim2.fromScale(1, 1)
	addCorner(targetSwatch)
	targetSwatch.Parent = targetIcon.slot
	targetIcon.fallback.Font = BODY_FONT

	local status = makeText("Status", screenGui, BODY_FONT)
	status.AnchorPoint = Vector2.new(0.5, 0)
	status.Position = UDim2.fromScale(0.5, HUD.statusY)
	status.Size = UDim2.fromScale(HUD.statusSize[1], HUD.statusSize[2])

	-- Timer bar: stopwatch icon, then a track whose fill shrinks to the server's endsAt.
	local timerPanel, timerIcon, timerBody, timerText = makeBadge(
		"TimerBar",
		HUD.timerSize,
		Vector2.new(0.5, 1),
		UDim2.fromScale(0.5, 1 - HUD.timerBottom),
		screenGui
	)
	setIcon(timerIcon, { { id = Config.Assets.Images.stopwatch, tint = UNTINTED } }, "")
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.BackgroundColor3 = toColor3(HUD.timerTrackRgb)
	track.BorderSizePixel = 0
	track.Size = UDim2.fromScale(1, 1)
	addCorner(track)
	track.Parent = timerBody
	local timerFill = Instance.new("Frame")
	timerFill.Name = "Fill"
	timerFill.BackgroundColor3 = toColor3(HUD.timerFillRgb)
	timerFill.BackgroundTransparency = 0.6
	timerFill.BorderSizePixel = 0
	timerFill.Size = UDim2.fromScale(1, 1)
	addCorner(timerFill)
	timerFill.Parent = track
	local timerScale = Instance.new("UIScale")
	timerScale.Parent = timerPanel

	-- Centre banner (D-12): a title over a subtitle.
	local BANNER = Config.Banner
	local banner = Instance.new("Frame")
	banner.Name = "Banner"
	banner.AnchorPoint = Vector2.new(0.5, 0.5)
	banner.Position = UDim2.fromScale(0.5, BANNER.centerY)
	banner.Size = UDim2.fromScale(BANNER.size[1], BANNER.size[2])
	banner.BackgroundColor3 = toColor3(HUD.panelRgb)
	banner.BackgroundTransparency = HUD.panelTransparency
	banner.BorderSizePixel = 0
	banner.Visible = false
	addCorner(banner)
	addPadding(banner)
	local bannerScale = Instance.new("UIScale")
	bannerScale.Parent = banner
	local bannerTitle = makeText("Title", banner, HEADING_FONT, BANNER.maxTitleSize)
	bannerTitle.Size = UDim2.fromScale(1, BANNER.titleShare)
	local bannerSubtitle = makeText("Subtitle", banner, BODY_FONT, BANNER.maxSubtitleSize)
	bannerSubtitle.Position = UDim2.fromScale(0, BANNER.titleShare)
	bannerSubtitle.Size = UDim2.fromScale(1, 1 - BANNER.titleShare)
	banner.Parent = screenGui

	-- Lobby panel (D-13): title, players ready and status, stacked on the left.
	local LOBBY = Config.Lobby
	local lobbyPanel = makePanel(
		"LobbyPanel",
		LOBBY.panelSize,
		Vector2.new(0, 0.5),
		UDim2.fromScale(LOBBY.margin, LOBBY.centerY)
	)
	local lobbyLayout = Instance.new("UIListLayout")
	lobbyLayout.FillDirection = Enum.FillDirection.Vertical
	lobbyLayout.SortOrder = Enum.SortOrder.LayoutOrder
	lobbyLayout.Parent = lobbyPanel
	local lobbyRows: { TextLabel } = {}
	for index, rowName in { "Title", "Count", "Status" } do
		local font = if index == 1 then HEADING_FONT else BODY_FONT
		local row = makeText(rowName, lobbyPanel, font)
		row.LayoutOrder = index
		row.Size = UDim2.fromScale(1, 1 / 3)
		lobbyRows[index] = row
	end
	lobbyPanel.Parent = screenGui

	-- Results panel (D-15): crown and title, subtitle, then one row per player, best first.
	local RESULTS = Config.Results
	local results = makePanel(
		"Results",
		RESULTS.size,
		Vector2.new(0.5, 0.5),
		UDim2.fromScale(0.5, RESULTS.centerY)
	)
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundTransparency = 1
	header.Size = UDim2.fromScale(1, RESULTS.headerShare)
	header.Parent = results
	local headerLayout = Instance.new("UIListLayout")
	headerLayout.FillDirection = Enum.FillDirection.Horizontal
	headerLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	headerLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	headerLayout.Padding = UDim.new(0, HUD.padding)
	headerLayout.SortOrder = Enum.SortOrder.LayoutOrder
	headerLayout.Parent = header
	local resultsCrown = makeIcon(header, 0.15)
	resultsCrown.slot.LayoutOrder = 1
	setIcon(resultsCrown, { { id = Config.Assets.Images.crown, tint = UNTINTED } }, "")
	local resultsTitle = makeText("Title", header, HEADING_FONT, Config.Banner.maxTitleSize)
	resultsTitle.LayoutOrder = 2
	resultsTitle.Size = UDim2.fromScale(0.8, 1)
	local resultsSubtitle = makeText("Subtitle", results, BODY_FONT)
	resultsSubtitle.Position = UDim2.fromScale(0, RESULTS.headerShare)
	resultsSubtitle.Size = UDim2.fromScale(1, RESULTS.subtitleShare)

	local listTop = RESULTS.headerShare + RESULTS.subtitleShare
	local rowHeight = (1 - listTop) / (RESULTS.maxRows + 1) -- one extra line for "+N more"
	local resultsRows: { ResultRow } = {}
	for index = 1, RESULTS.maxRows do
		local frame = Instance.new("Frame")
		frame.Name = "Row" .. index
		frame.BackgroundColor3 = toColor3(RESULTS.selfRgb)
		frame.BorderSizePixel = 0
		frame.Position = UDim2.fromScale(0, listTop + (index - 1) * rowHeight)
		frame.Size = UDim2.fromScale(1, rowHeight)
		addCorner(frame)
		frame.Parent = results
		local place = makeText("Place", frame, HEADING_FONT)
		place.Size = UDim2.fromScale(RESULTS.placeShare, 1)
		local name = makeText("Name", frame, BODY_FONT)
		name.Position = UDim2.fromScale(RESULTS.placeShare, 0)
		name.Size = UDim2.fromScale(1 - RESULTS.placeShare - RESULTS.detailShare, 1)
		name.TextXAlignment = Enum.TextXAlignment.Left
		local detail = makeText("Detail", frame, BODY_FONT)
		detail.Position = UDim2.fromScale(1 - RESULTS.detailShare, 0)
		detail.Size = UDim2.fromScale(RESULTS.detailShare, 1)
		resultsRows[index] = { frame = frame, place = place, name = name, detail = detail }
	end
	local resultsMore = makeText("More", results, BODY_FONT)
	resultsMore.Position = UDim2.fromScale(0, listTop + RESULTS.maxRows * rowHeight)
	resultsMore.Size = UDim2.fromScale(1, rowHeight)
	results.Parent = screenGui

	screenGui.Parent = playerGui
	hudGui = screenGui
	return {
		roundPanel = roundPanel,
		roundText = roundText,
		playersPanel = playersPanel,
		playersText = playersText,
		targetPanel = targetPanel,
		targetIcon = targetIcon,
		targetSwatch = targetSwatch,
		targetName = targetName,
		status = status,
		timerPanel = timerPanel,
		timerScale = timerScale,
		timerFill = timerFill,
		timerText = timerText,
		banner = banner,
		bannerScale = bannerScale,
		bannerTitle = bannerTitle,
		bannerSubtitle = bannerSubtitle,
		lobbyPanel = lobbyPanel,
		lobbyTitle = lobbyRows[1],
		lobbyCount = lobbyRows[2],
		lobbyStatus = lobbyRows[3],
		results = results,
		resultsTitle = resultsTitle,
		resultsSubtitle = resultsSubtitle,
		resultsRows = resultsRows,
		resultsMore = resultsMore,
	}
end

local function setText(label: TextLabel, text: string)
	if label.Text ~= text then
		label.Text = text
	end
end

local function drawTarget(w: Widgets, card: HudModel.TargetCard?)
	w.targetPanel.Visible = card ~= nil
	if not card then
		return
	end
	setText(w.targetName, card.name)
	local icon = w.targetIcon
	if card.hidden or not card.shape or not card.hex then
		-- Secret target: no color and no shape, only the hidden mark.
		icon.image.Visible = false
		w.targetSwatch.Visible = false
		icon.fallback.Visible = true
		icon.fallback.Text = HUD.hiddenText
		return
	end
	local color = hexColor(card.hex)
	local shape: ShapeId = card.shape
	local images = Config.Assets.Images
	setIcon(icon, {
		{ id = images.shapeTile[shape], tint = UNTINTED },
		{ id = images.shapeIcon[shape], tint = color },
	}, shape)
	w.targetSwatch.BackgroundColor3 = color
	w.targetSwatch.Visible = icon.failed
end

local function drawTimer(w: Widgets, timer: HudModel.TimerView?, now: number)
	w.timerPanel.Visible = timer ~= nil
	if not timer then
		return
	end
	setText(w.timerText, timer.text)
	w.timerFill.Size = UDim2.fromScale(timer.fraction, 1)
	local fillRgb = if timer.warning then HUD.warningRgb else HUD.timerFillRgb
	w.timerFill.BackgroundColor3 = toColor3(fillRgb)
	w.timerFill.BackgroundTransparency = if timer.warning then 0 else 0.6
	if timer.warning then
		-- Grows and shrinks pulseHz times a second, by up to pulseScale.
		local wave = 0.5 + 0.5 * math.sin(now * HUD.pulseHz * 2 * math.pi)
		w.timerScale.Scale = 1 + HUD.pulseScale * wave
	else
		w.timerScale.Scale = 1
	end
end

local BANNER_TITLE_RGB: { [BannerModel.Kind]: { number } } = {
	Intermission = HUD.textRgb,
	Round = HUD.textRgb,
	Final = Config.Banner.finalRgb,
	Replay = Config.Banner.replayRgb,
}

-- The banner last drawn, so a new one pops in once instead of every frame.
local shownBannerKey: string? = nil

local function drawBanner(w: Widgets, banner: BannerModel.Banner?, endsAt: number?, now: number)
	w.banner.Visible = banner ~= nil
	if not banner then
		shownBannerKey = nil
		return
	end
	setText(w.bannerTitle, banner.title)
	setText(w.bannerSubtitle, banner.subtitle)
	w.bannerTitle.TextColor3 = toColor3(BANNER_TITLE_RGB[banner.kind])

	local key = banner.kind .. "|" .. banner.title
	if key ~= shownBannerKey then
		shownBannerKey = key
		w.bannerScale.Scale = Config.Banner.popStartScale
		local info =
			TweenInfo.new(Config.Banner.popSeconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		TweenService:Create(w.bannerScale, info, { Scale = 1 }):Play()
	end

	-- Fade out over the last fadeSeconds of the state: the panel, the text and its outline
	-- together. (A CanvasGroup faded only the panel in Studio QA, so each part fades itself.)
	local fadeSeconds = Config.Banner.fadeSeconds
	local remaining = if endsAt then endsAt - now else math.huge
	local fade = if fadeSeconds > 0 then 1 - math.clamp(remaining / fadeSeconds, 0, 1) else 0
	w.banner.BackgroundTransparency = HUD.panelTransparency + (1 - HUD.panelTransparency) * fade
	for _, label in { w.bannerTitle, w.bannerSubtitle } do
		label.TextTransparency = fade
		local stroke = label:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Transparency = fade
		end
	end
end

local function drawLobby(w: Widgets, lobby: LobbyModel.View?)
	w.lobbyPanel.Visible = lobby ~= nil
	if not lobby then
		return
	end
	setText(w.lobbyTitle, lobby.title)
	w.lobbyCount.Visible = lobby.count ~= nil
	setText(w.lobbyCount, lobby.count or "")
	setText(w.lobbyStatus, lobby.status)
end

local function drawResults(w: Widgets, view: ResultsModel.View?)
	w.results.Visible = view ~= nil
	if not view then
		return
	end
	setText(w.resultsTitle, view.title)
	setText(w.resultsSubtitle, view.subtitle)
	for index, row in w.resultsRows do
		local data = view.rows[index]
		row.frame.Visible = data ~= nil
		if data then
			setText(row.place, data.place)
			setText(row.name, data.name)
			setText(row.detail, data.detail)
			row.place.TextColor3 =
				toColor3(if data.winner then Config.Results.winnerRgb else HUD.textRgb)
			-- Only the local player's row has a background.
			row.frame.BackgroundTransparency = if data.isSelf then 0 else 1
		end
	end
	w.resultsMore.Visible = view.more > 0
	setText(w.resultsMore, string.format("+%d more", view.more))
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

	local widgets = buildGui()
	local model = HudModel.new()
	local lobbyInfo: Types.LobbyInfoPayload? = nil
	local localPlayer = Players.LocalPlayer

	local function render()
		local now = workspace:GetServerTimeNow()
		local view = HudModel.view(model, now)
		-- The banner says what the status line would, so the status line steps aside for it.
		local banner = BannerModel.view(model, now)
		drawBanner(widgets, banner, model.endsAt, now)
		local role = localPlayer:GetAttribute("MatchRole")
		local lobby =
			LobbyModel.view(if type(role) == "string" then role else nil, model.state, lobbyInfo)
		drawLobby(widgets, lobby)
		-- In the lobby the panel says what the status line would; spectators keep the status
		-- line, since it describes the match they are watching.
		local lobbySaysIt = lobby ~= nil and model.state == "Lobby"
		local resultsView = if model.state == "Victory" and model.matchResult
			then ResultsModel.view(model.matchResult, localPlayer.UserId, Config.Results.maxRows)
			else nil
		drawResults(widgets, resultsView)
		-- The banner, the lobby panel and the results panel each replace the status line.
		widgets.status.Visible = banner == nil and not lobbySaysIt and resultsView == nil
		setText(widgets.status, view.status)

		widgets.roundPanel.Visible = view.roundText ~= nil
		setText(widgets.roundText, view.roundText or "")

		widgets.playersPanel.Visible = view.playersLeft ~= nil
		setText(widgets.playersText, view.playersLeft or "")

		drawTarget(widgets, view.target)
		drawTimer(widgets, view.timer, now)
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
		HudModel.applyTarget(model, payload, workspace:GetServerTimeNow())
		render()
	end)
	Remotes.PlayerEliminated.connect(function(payload)
		HudModel.applyEliminated(model, payload)
		render()
	end)
	Remotes.LobbyInfo.connect(function(payload)
		lobbyInfo = payload
		render()
	end)
	Remotes.MatchResult.connect(function(payload)
		HudModel.applyMatchResult(model, payload)
		render()
	end)

	-- The timer and the reveal change between remotes; setText skips unchanged labels.
	RunService.Heartbeat:Connect(render)
	render()
end

return HUDController
