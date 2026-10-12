--!strict
-- Menu overlay and join queue buttons (D-16). Players start here, over the live match, with
-- the camera circling the arena. Play and Leave only send requests; the server decides and
-- answers through the MatchRole attribute.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local LeaderboardRules = require(ReplicatedStorage.Shared.LeaderboardRules)
local SettingsRules = require(ReplicatedStorage.Shared.SettingsRules)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local HUDController = require(script.Parent.HUDController)
local MenuModel = require(script.Parent.MenuModel)
local Sfx = require(script.Parent.Sfx)
local UiStyle = require(script.Parent.UiStyle)

local MATCH_ROLE_ATTRIBUTE = "MatchRole"
-- Above the HUD.
local MENU_DISPLAY_ORDER = 10

local MenuController = {}

local started = false
local player = Players.LocalPlayer
local currentState: Types.MatchState? = nil
local orbitConnection: RBXScriptConnection? = nil
local orbitStartedAt = 0

local function toColor3(rgb: { number }): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

local function addCorner(parent: GuiObject)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, Config.Menu.cornerRadius)
	corner.Parent = parent
end

local function addTextLimit(parent: GuiObject)
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = Config.Menu.maxTextSize
	limit.Parent = parent
end

-- A button drawn with the artist's button art (Play, Leave). If the art is not uploaded (ID 0)
-- or fails to load, a plain rounded button in `rgb` with `fallbackText` stands in. The height
-- follows the art's `aspect` (width / height); callers set Position and the width.
local function makeArtButton(
	name: string,
	id: number,
	fallbackText: string,
	rgb: { number },
	aspect: number
): ImageButton
	local button = Instance.new("ImageButton")
	button.Name = name
	button.BackgroundTransparency = 1
	button.BackgroundColor3 = toColor3(rgb)
	button.ScaleType = Enum.ScaleType.Fit
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = aspect
	ratio.DominantAxis = Enum.DominantAxis.Width
	ratio.Parent = button

	local fallback = Instance.new("TextLabel")
	fallback.Name = "Fallback"
	fallback.Text = fallbackText
	fallback.TextScaled = true
	fallback.Font = UiStyle.HEADING_FONT
	fallback.TextColor3 = toColor3(Config.Menu.textRgb)
	fallback.BackgroundTransparency = 1
	fallback.Size = UDim2.fromScale(1, 1)
	fallback.Visible = false
	addTextLimit(fallback)
	fallback.Parent = button

	local function useFallback()
		button.Image = ""
		button.BackgroundTransparency = 0
		addCorner(button)
		fallback.Visible = true
	end
	if id == 0 then
		useFallback()
	else
		button.Image = "rbxassetid://" .. tostring(id)
		task.spawn(function()
			ContentProvider:PreloadAsync({ button }, function(_, status)
				if status ~= Enum.AssetFetchStatus.Success then
					warn(
						string.format(
							"[Menu] %s art %d did not load (%s)",
							name,
							id,
							tostring(status)
						)
					)
					useFallback()
				end
			end)
		end)
	end
	return button
end

-- A tile that shows its art but is not wired up yet (D-09, A-06). Dimmed and marked
-- "Coming soon", and not clickable, so it cannot promise something that does nothing.
local function makeSoonArtTile(
	name: string,
	id: number,
	rgb: { number },
	aspect: number
): ImageButton
	local tile = makeArtButton(name, id, name, rgb, aspect)
	tile.Active = false
	tile.AutoButtonColor = false
	tile.ImageTransparency = Config.Menu.soonTransparency
	local soon = UiStyle.makeText("Soon", tile, UiStyle.BODY_FONT)
	soon.AnchorPoint = Vector2.new(0.5, 1)
	soon.Position = UDim2.fromScale(0.5, 1)
	soon.Size = UDim2.fromScale(1, 0.32)
	soon.Text = "Coming soon"
	return tile
end

-- The settings panel (A-07): music and effects volume.
--
-- Pressing a step changes what this client hears straight away, so the button feels
-- instant, and sends the new values to the server to be saved. The server clamps them and
-- answers with the profile, which is what the panel then shows: the client never decides
-- what is stored.
local function makeSettingsPanel(parent: Instance): (Frame, (Types.PlayerProfile) -> ())
	local menu = Config.Menu
	local settings = Config.Settings
	local panel = UiStyle.makePanel(
		"SettingsPanel",
		menu.settingsPanelSize,
		Vector2.new(0.5, 0.5),
		UDim2.fromScale(0.5, 0.5)
	)
	panel.Visible = false
	panel.Parent = parent

	local title = UiStyle.makeText("Title", panel, UiStyle.HEADING_FONT)
	title.Size = UDim2.fromScale(1, 0.16)
	title.Text = settings.title

	-- What this client currently believes, applied locally and sent to the server. It is
	-- replaced by whatever the server confirms.
	local music = 100
	local sfx = 100

	local function apply()
		Sfx.setScales(SettingsRules.scale(music), SettingsRules.scale(sfx))
	end

	local function send()
		Remotes.RequestSettings.fire({ music = music, sfx = sfx })
	end

	-- One row: a name, minus, the value, plus.
	local function makeRow(name: string, y: number, get: () -> number, set: (number) -> ())
		local label = UiStyle.makeText(name .. "Label", panel, UiStyle.BODY_FONT)
		label.Position = UDim2.fromScale(0.05, y)
		label.Size = UDim2.fromScale(0.35, 0.14)
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.Text = name

		local value = UiStyle.makeText(name .. "Value", panel, UiStyle.BODY_FONT)
		value.Position = UDim2.fromScale(0.58, y)
		value.Size = UDim2.fromScale(0.2, 0.14)

		local function refresh()
			value.Text = SettingsRules.label(get())
		end

		local function makeStep(text: string, x: number, delta: number)
			local button = UiStyle.makeButton(name .. text, text, menu.settingsStepRgb)
			button.Position = UDim2.fromScale(x, y)
			button.Size = UDim2.fromScale(0.14, 0.14)
			button.Parent = panel
			button.Activated:Connect(function()
				set(SettingsRules.step(get(), delta, settings.stepPercent))
				refresh()
				apply()
				send()
			end)
		end
		makeStep("-", 0.42, -1)
		makeStep("+", 0.8, 1)
		return refresh
	end

	local refreshMusic = makeRow("Music", menu.settingsRowY[1], function()
		return music
	end, function(v)
		music = v
	end)
	local refreshSfx = makeRow("Effects", menu.settingsRowY[2], function()
		return sfx
	end, function(v)
		sfx = v
	end)

	local close = UiStyle.makeButton("Close", "Close", menu.leaderboardRgb)
	close.AnchorPoint = Vector2.new(0.5, 1)
	close.Position = UDim2.fromScale(0.5, 1)
	close.Size = UDim2.fromScale(0.4, 0.15)
	close.Parent = panel
	close.Activated:Connect(function()
		panel.Visible = false
	end)

	-- The server's copy wins. This also runs on join, which is how saved settings come
	-- back and get applied before the player touches anything.
	local function update(profile: Types.PlayerProfile)
		music = SettingsRules.clampPercent(profile.musicPercent)
		sfx = SettingsRules.clampPercent(profile.sfxPercent)
		refreshMusic()
		refreshSfx()
		apply()
	end

	return panel, update
end

-- The daily rewards panel (A-08), opened from the menu's Daily Rewards tile.
--
-- The server owns the clock and the decision. This draws the track, counts down locally
-- between updates purely so the number moves, and sends a claim request that the server
-- is free to refuse.
local function makeDailyPanel(parent: Instance): (Frame, (Types.DailyPayload) -> ())
	local menu = Config.Menu
	local daily = Config.Daily
	local panel = UiStyle.makePanel(
		"DailyPanel",
		menu.leaderboardPanelSize,
		Vector2.new(0.5, 0.5),
		UDim2.fromScale(0.5, 0.5)
	)
	panel.Visible = false
	panel.Parent = parent

	local title = UiStyle.makeText("Title", panel, UiStyle.HEADING_FONT)
	title.Size = UDim2.fromScale(1, 0.12)
	title.Text = daily.title

	-- One tile per day of the track, in a row.
	local dayTiles: { { frame: Frame, label: TextLabel } } = {}
	local count = #daily.track
	for index = 1, count do
		local tile = Instance.new("Frame")
		tile.Name = "Day" .. index
		tile.Size = UDim2.fromScale(0.9 / count - 0.01, 0.2)
		tile.Position = UDim2.fromScale(0.05 + (index - 1) * (0.9 / count), 0.18)
		tile.BackgroundColor3 = UiStyle.toColor3(menu.dailyTileRgb)
		tile.BorderSizePixel = 0
		UiStyle.addCorner(tile)
		tile.Parent = panel
		local label = UiStyle.makeText("Coins", tile, UiStyle.BODY_FONT)
		label.Text = tostring(daily.track[index])
		table.insert(dayTiles, { frame = tile, label = label })
	end

	local status = UiStyle.makeText("Status", panel, UiStyle.BODY_FONT)
	status.Position = UDim2.fromScale(0, 0.44)
	status.Size = UDim2.fromScale(1, 0.12)

	local claim = UiStyle.makeButton("Claim", "Claim", menu.dailyClaimRgb)
	claim.AnchorPoint = Vector2.new(0.5, 0)
	claim.Position = UDim2.fromScale(0.5, 0.62)
	claim.Size = UDim2.fromScale(0.5, 0.13)
	claim.Parent = panel

	local close = UiStyle.makeButton("Close", "Close", menu.leaderboardRgb)
	close.AnchorPoint = Vector2.new(0.5, 1)
	close.Position = UDim2.fromScale(0.5, 1)
	close.Size = UDim2.fromScale(0.4, 0.11)
	close.Parent = panel
	close.Activated:Connect(function()
		panel.Visible = false
	end)

	local latest: Types.DailyPayload? = nil
	-- Counts down between server updates so the clock looks alive. It is display only:
	-- whether a claim is actually due is the server's call, re-checked on every update.
	local remaining = 0

	local function draw()
		local payload = latest
		if not payload then
			return
		end
		for index, tile in dayTiles do
			local claimed = index < payload.trackDay
				or (index == payload.trackDay and not payload.canClaim)
			local isNext = index == payload.trackDay and payload.canClaim
			tile.frame.BackgroundColor3 = UiStyle.toColor3(
				if isNext
					then menu.dailyNextRgb
					elseif claimed then menu.dailyDoneRgb
					else menu.dailyTileRgb
			)
		end
		claim.Visible = payload.canClaim
		if payload.canClaim then
			status.Text = string.format("Day %d: %d coins", payload.trackDay, payload.reward)
		else
			local hours = math.floor(remaining / 3600)
			local minutes = math.floor((remaining % 3600) / 60)
			status.Text = string.format("%s  %dh %dm", daily.claimedMessage, hours, minutes)
		end
	end

	task.spawn(function()
		while true do
			task.wait(1)
			if remaining > 0 then
				remaining -= 1
				if panel.Visible then
					draw()
				end
			end
		end
	end)

	claim.Activated:Connect(function()
		Remotes.RequestDailyClaim.fire()
	end)

	local function update(payload: Types.DailyPayload)
		latest = payload
		remaining = payload.secondsUntilNext
		draw()
	end

	return panel, update
end

-- The top players panel (A-05), opened from the menu's Leaderboard tile.
--
-- The server sends the rows; this only draws them. The same rows are on the board in the
-- lobby, so the two can never disagree.
local function makeLeaderboardPanel(parent: Instance): (Frame, (Types.LeaderboardPayload) -> ())
	local menu = Config.Menu
	local board = Config.Leaderboard
	local panel = UiStyle.makePanel(
		"LeaderboardPanel",
		menu.leaderboardPanelSize,
		Vector2.new(0.5, 0.5),
		UDim2.fromScale(0.5, 0.5)
	)
	panel.Visible = false
	panel.Parent = parent

	local title = UiStyle.makeText("Title", panel, UiStyle.HEADING_FONT)
	title.Size = UDim2.fromScale(1, 0.12)
	title.Text = board.title
	title.TextColor3 = UiStyle.toColor3(board.titleRgb)

	-- One row of labels per place, filled on every update.
	local rows: { { left: TextLabel, right: TextLabel } } = {}
	for index = 1, board.topCount do
		local y = 0.14 + (index - 1) * menu.leaderboardRowHeight
		local left = UiStyle.makeText("Row" .. index, panel, UiStyle.BODY_FONT)
		left.Position = UDim2.fromScale(0, y)
		left.Size = UDim2.fromScale(0.75, menu.leaderboardRowHeight)
		left.TextXAlignment = Enum.TextXAlignment.Left
		local right = UiStyle.makeText("Wins" .. index, panel, UiStyle.BODY_FONT)
		right.Position = UDim2.fromScale(0.75, y)
		right.Size = UDim2.fromScale(0.25, menu.leaderboardRowHeight)
		right.TextXAlignment = Enum.TextXAlignment.Right
		table.insert(rows, { left = left, right = right })
	end

	-- Sits over the rows when there is nothing to show.
	local status = UiStyle.makeText("Status", panel, UiStyle.BODY_FONT)
	status.Position = UDim2.fromScale(0, 0.42)
	status.Size = UDim2.fromScale(1, 0.14)
	status.Visible = false

	local close = UiStyle.makeButton("Close", "Close", menu.leaderboardRgb)
	close.AnchorPoint = Vector2.new(0.5, 1)
	close.Position = UDim2.fromScale(0.5, 1)
	close.Size = UDim2.fromScale(0.4, 0.11)
	close.Parent = panel
	close.Activated:Connect(function()
		panel.Visible = false
	end)

	local function update(payload: Types.LeaderboardPayload)
		local message = LeaderboardRules.statusMessage(
			payload.offline,
			#payload.rows,
			board.offlineMessage,
			board.emptyMessage
		)
		status.Visible = message ~= nil
		status.Text = message or ""
		for index, labels in rows do
			local row = payload.rows[index]
			if row and not message then
				local left, right = LeaderboardRules.rowText(row, board.maxNameLength)
				labels.left.Text = left
				labels.right.Text = right
			else
				labels.left.Text = ""
				labels.right.Text = ""
			end
		end
	end

	return panel, update
end

-- How to play (D-09): the tagline, three steps, and every color with its shape, from Config.
local function makeHowToCard(parent: Instance): Frame
	local menu = Config.Menu
	local card = UiStyle.makePanel(
		"HowToPlay",
		menu.howToSize,
		Vector2.new(1, 1),
		UDim2.fromScale(menu.howToCorner[1], menu.howToCorner[2])
	)
	card.Visible = true
	local tagline = UiStyle.makeText("Tagline", card, UiStyle.HEADING_FONT)
	tagline.Size = UDim2.fromScale(1, 0.22)
	tagline.Text = MenuModel.TAGLINE
	for index, step in MenuModel.STEPS do
		local line = UiStyle.makeText("Step" .. index, card, UiStyle.BODY_FONT)
		line.Position = UDim2.fromScale(0, 0.22 + (index - 1) * 0.12)
		line.Size = UDim2.fromScale(1, 0.12)
		line.TextXAlignment = Enum.TextXAlignment.Left
		line.Text = step
	end

	local row = Instance.new("Frame")
	row.Name = "Pairs"
	row.BackgroundTransparency = 1
	row.Position = UDim2.fromScale(0, 0.6)
	row.Size = UDim2.fromScale(1, 0.4)
	row.Parent = card
	local pairsList = MenuModel.pairs(Config.Colors)
	local width = 1 / #pairsList
	for index, pair in pairsList do
		local slot = Instance.new("Frame")
		slot.Name = pair.label
		slot.BackgroundTransparency = 1
		slot.Position = UDim2.fromScale((index - 1) * width, 0)
		slot.Size = UDim2.fromScale(width, 1)
		slot.Parent = row
		local tile = Instance.new("ImageLabel")
		tile.Name = "Tile"
		tile.BackgroundTransparency = 1
		tile.ScaleType = Enum.ScaleType.Fit
		tile.Size = UDim2.fromScale(1, 0.72)
		local id = Config.Assets.Images.shapeTile[pair.shape]
		tile.Image = if id ~= 0 then UiStyle.assetUrl(id) else ""
		tile.Parent = slot
		local label = UiStyle.makeText("Label", slot, UiStyle.BODY_FONT)
		-- A little narrower than the slot, so long names (Orange, Yellow) do not touch.
		label.Position = UDim2.fromScale(0.06, 0.72)
		label.Size = UDim2.fromScale(0.88, 0.28)
		label.Text = pair.label
	end
	card.Parent = parent
	return card
end

type Gui = { panel: Frame, play: ImageButton, leave: ImageButton }

local function buildGui(): Gui
	local menu = Config.Menu
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "Menu"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = MENU_DISPLAY_ORDER
	screenGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets

	-- The title screen over the live match, with the camera circling the arena.
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundColor3 = toColor3(menu.backdropRgb)
	panel.BackgroundTransparency = menu.backdropTransparency
	panel.BorderSizePixel = 0
	panel.Parent = screenGui

	-- Logo, with the game's name as text if the art is missing or fails to load.
	local logo = Instance.new("ImageLabel")
	logo.Name = "Logo"
	logo.BackgroundTransparency = 1
	logo.ScaleType = Enum.ScaleType.Fit
	logo.Position = UDim2.fromScale(menu.logoPosition[1], menu.logoPosition[2])
	logo.Size = UDim2.fromScale(menu.logoSize[1], menu.logoSize[2])
	logo.Parent = panel
	local title = UiStyle.makeText("Title", logo, UiStyle.HEADING_FONT)
	title.Text = "Color Panic"
	title.Visible = false
	local logoId = Config.Assets.Images.logo
	if logoId == 0 then
		title.Visible = true
	else
		logo.Image = UiStyle.assetUrl(logoId)
		task.spawn(function()
			ContentProvider:PreloadAsync({ logo }, function(_, status)
				if status ~= Enum.AssetFetchStatus.Success then
					title.Visible = true
				end
			end)
		end)
	end

	-- Play, then the two tiles that are not built yet, in a column under the logo.
	local play =
		makeArtButton("Play", Config.Assets.Images.play, "Play", menu.buttonRgb, menu.playAspect)
	play.Position = UDim2.fromScale(menu.buttonsX, menu.playY)
	play.Size = UDim2.fromScale(menu.playWidth, 1)
	play.Parent = panel
	local assets = Config.Assets.Images
	local aspect = menu.tileAspect
	-- Shop is the only tile still waiting on a feature (A-07 wired Settings up).
	local shop = makeSoonArtTile("Shop", assets.menuShop, menu.shopRgb, aspect.shop)
	local settings = makeArtButton(
		"Settings",
		assets.menuSettings,
		"Settings",
		menu.settingsRgb,
		aspect.settings
	)
	-- Unlike the two above, these work, so they are live buttons (A-05, A-08).
	local leaderboard = makeArtButton(
		"Leaderboard",
		assets.menuLeaderboard,
		"Leaderboard",
		menu.leaderboardRgb,
		aspect.leaderboard
	)
	local dailyRewards = makeArtButton(
		"DailyRewards",
		assets.menuDailyRewards,
		"Daily Rewards",
		menu.dailyRgb,
		aspect.dailyRewards
	)
	-- The width is set here; each tile's height comes from its art's aspect ratio.
	for _, tile in { settings, shop, leaderboard, dailyRewards } do
		tile.Size = UDim2.fromScale(menu.soonSize[1], 1)
		tile.Parent = panel
	end

	-- Built before the panels so they can hide it while one is open.
	local howTo = makeHowToCard(panel)

	local leaderboardPanel, updateLeaderboard = makeLeaderboardPanel(panel)
	local dailyPanel, updateDaily = makeDailyPanel(panel)
	local settingsPanel, updateSettings = makeSettingsPanel(panel)
	-- Only one panel at a time, so they cannot stack on top of each other.
	--
	-- A panel also has to draw over the how-to card. Everything in the menu sat at ZIndex
	-- 1, so draw order fell back to sibling order and the card, built last, covered the
	-- panels: in Studio the Claim and Close buttons were hidden behind it. The panels are
	-- lifted above it, and the card is hidden while one is open, since a card showing
	-- through from underneath is just noise.
	local panels = { leaderboardPanel, dailyPanel, settingsPanel }
	for _, each in panels do
		-- The whole subtree is lifted, not just the panel. Under the Sibling ZIndex rule a
		-- child below its parent's ZIndex draws behind it, so raising the panel alone put
		-- its own background over its title, rows and buttons and left them washed out.
		each.ZIndex = menu.panelZIndex
		for _, child in each:GetDescendants() do
			if child:IsA("GuiObject") then
				child.ZIndex = menu.panelZIndex
			end
		end
	end
	local function openOnly(target: Frame)
		local opening = not target.Visible
		for _, other in panels do
			other.Visible = other == target and opening
		end
		howTo.Visible = not opening
	end
	leaderboard.Activated:Connect(function()
		openOnly(leaderboardPanel)
	end)
	dailyRewards.Activated:Connect(function()
		openOnly(dailyPanel)
	end)
	settings.Activated:Connect(function()
		openOnly(settingsPanel)
	end)
	Remotes.LeaderboardUpdated.connect(updateLeaderboard)
	Remotes.DailyUpdated.connect(updateDaily)
	-- Saved settings arrive with the profile, on join and after every change.
	Remotes.PlayerDataUpdated.connect(function(payload)
		updateSettings(payload.profile)
	end)
	-- The Play button's height follows its art, so the tiles are placed from its drawn size.
	--
	-- Each tile's height comes from its own art, and four of them at the full tile width do
	-- not fit under Play: measured in Studio at 1529 by 575, the column wanted 932 pixels of
	-- a 517 pixel panel and three tiles fell off the bottom. So the width is chosen to make
	-- the column fit the space that is actually left, never wider than the configured size.
	-- Two rows of two, rather than one column of four. Measured in Studio at 1529 by 575,
	-- four stacked tiles needed more height than the panel had, and shrinking them to fit
	-- would have taken them under the touch minimum, so they are paired instead. A row is
	-- as tall as its squarer tile, which is the one with the smaller aspect.
	local rows = { { dailyRewards, leaderboard }, { shop, settings } }
	local rowAspect = {
		math.min(menu.tileAspect.dailyRewards, menu.tileAspect.leaderboard),
		math.min(menu.tileAspect.shop, menu.tileAspect.settings),
	}
	local inverseAspects = 1 / rowAspect[1] + 1 / rowAspect[2]
	local column = { dailyRewards, leaderboard, shop, settings }

	local function placeTiles()
		local panelHeight = panel.AbsoluteSize.Y
		local panelWidth = panel.AbsoluteSize.X
		if panelHeight <= 0 or panelWidth <= 0 then
			return -- not laid out yet; this runs again when the panel gets a size
		end

		local top = menu.playY + play.AbsoluteSize.Y / panelHeight + menu.soonGap
		local available = (1 - top - menu.soonGap * (#rows + 1)) * panelHeight
		-- A tile's height is its width over its aspect, so the two rows together are the
		-- shared width times the sum of one over each row's aspect. Solve that for width.
		local fitWidth = available / (panelWidth * inverseAspects)
		-- Never below the touch minimum. The floor is set by the flattest tile, since at a
		-- shared width that is the shortest one: sizing from the squarer tile left
		-- Leaderboard at 46 pixels, just under the minimum, while the rest passed.
		local flattest = math.max(
			menu.tileAspect.dailyRewards,
			menu.tileAspect.leaderboard,
			menu.tileAspect.shop,
			menu.tileAspect.settings
		)
		local minWidth = Config.Touch.minButtonPixels * flattest / panelWidth
		local width = math.max(math.min(menu.soonSize[1], fitWidth), minWidth)

		local y = top
		for index, row in rows do
			local x = menu.buttonsX
			local tallest = 0
			for _, tile in row do
				tile.Size = UDim2.fromScale(width, 1)
				tile.Position = UDim2.fromScale(x, y)
				x += width + menu.soonGap
				tallest = math.max(tallest, tile.AbsoluteSize.Y)
			end
			y += tallest / panelHeight + menu.soonGap
			if index == #rows then
				break
			end
		end
	end
	play:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeTiles)
	panel:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeTiles)
	for _, tile in column do
		tile:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeTiles)
	end

	-- Leave sits outside the panel: it shows in the lobby, when the menu is hidden (D-13).
	local lobby = Config.Lobby
	local leave = makeArtButton(
		"Leave",
		Config.Assets.Images.leave,
		"Leave",
		menu.leaveRgb,
		lobby.leaveAspect
	)
	-- Under the lobby panel at the top centre (D-09b).
	leave.AnchorPoint = Vector2.new(0.5, 0)
	leave.Position = UDim2.fromScale(0.5, Config.Hud.margin + lobby.topSize[2] + lobby.margin)
	leave.Size = UDim2.fromScale(lobby.leaveWidth, 1)
	leave.Parent = screenGui

	screenGui.Parent = player:WaitForChild("PlayerGui")
	placeTiles()
	return { panel = panel, play = play, leave = leave }
end

-- Circles the camera around the lobby island while the menu is up. The lobby is always
-- built, while the arena only has tiles during a round, so the arena centre is empty sky
-- between matches.
local function startOrbit()
	if orbitConnection then
		return
	end
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	orbitStartedAt = os.clock()
	local origin = Config.Placement.lobbyOrigin
	local center = Vector3.new(origin[1], origin[2] + Config.Menu.orbitLookHeight, origin[3])
	orbitConnection = RunService.RenderStepped:Connect(function()
		local menu = Config.Menu
		local p = MenuModel.orbitPosition(
			origin,
			menu.orbitRadius,
			menu.orbitHeight,
			menu.orbitSecondsPerTurn,
			os.clock() - orbitStartedAt
		)
		camera.CFrame = CFrame.lookAt(Vector3.new(p[1], p[2], p[3]), center)
	end)
end

-- Hands the camera back to Roblox's player camera, which follows the character once it spawns.
local function stopOrbit()
	if orbitConnection then
		orbitConnection:Disconnect()
		orbitConnection = nil
	end
	workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
end

function MenuController.start()
	assert(not started, "MenuController.start() called twice")
	started = true

	local gui = buildGui()

	local function render()
		local view = MenuModel.view(player:GetAttribute(MATCH_ROLE_ATTRIBUTE), currentState)
		gui.panel.Visible = view.menu
		gui.leave.Visible = view.leave
		HUDController.setVisible(view.hud)
		if view.menu then
			startOrbit()
		else
			stopOrbit()
		end
		-- A new role means the last request was answered, so the buttons work again.
		gui.play.Active = true
		gui.leave.Active = true
	end

	-- Buttons only send a request. They stay inactive until the server answers (the role
	-- changes) or the request cooldown passes, so a double tap sends one request.
	local function sendOnce(button: GuiButton, request: Remotes.ClientRequest)
		if not button.Active then
			return
		end
		button.Active = false
		Sfx.play("click")
		request.fire()
		task.delay(Config.Queue.requestCooldown, function()
			button.Active = true
		end)
	end

	gui.play.Activated:Connect(function()
		sendOnce(gui.play, Remotes.RequestPlay)
	end)
	gui.leave.Activated:Connect(function()
		sendOnce(gui.leave, Remotes.RequestLeave)
	end)

	player:GetAttributeChangedSignal(MATCH_ROLE_ATTRIBUTE):Connect(render)
	Remotes.StateChanged.connect(function(payload)
		currentState = payload.state
		render()
	end)
	render()
end

return MenuController
