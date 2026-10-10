--!strict
-- Menu overlay and join queue buttons (D-16). Players start here, over the live match, with
-- the camera circling the arena. Play and Leave only send requests; the server decides and
-- answers through the MatchRole attribute.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
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

-- A greyed tile for a feature that is not built yet (D-09): a label and "Coming soon". Not a
-- button, so nothing can be pressed.
local function makeSoonTile(name: string, rgb: { number }): Frame
	local tile = Instance.new("Frame")
	tile.Name = name
	tile.BackgroundColor3 = toColor3(rgb)
	tile.BackgroundTransparency = Config.Menu.soonTransparency
	tile.BorderSizePixel = 0
	UiStyle.addCorner(tile)
	UiStyle.addPadding(tile)
	UiStyle.addPanelStroke(tile)
	local label = UiStyle.makeText("Label", tile, UiStyle.HEADING_FONT)
	label.Size = UDim2.fromScale(0.6, 1)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = name
	local soon = UiStyle.makeText("Soon", tile, UiStyle.BODY_FONT)
	soon.Position = UDim2.fromScale(0.6, 0.15)
	soon.Size = UDim2.fromScale(0.4, 0.7)
	soon.Text = "Coming soon"
	return tile
end

-- How to play (D-09): the tagline, three steps, and every color with its shape, from Config.
local function makeHowToCard(parent: Instance)
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
	local settings = makeSoonTile("Settings", menu.settingsRgb)
	local shop = makeSoonTile("Shop", menu.shopRgb)
	for _, tile in { settings, shop } do
		tile.Size = UDim2.fromScale(menu.soonSize[1], menu.soonSize[2])
		tile.Parent = panel
	end
	-- The Play button's height follows its art, so the tiles are placed from its drawn size.
	local function placeTiles()
		local panelHeight = panel.AbsoluteSize.Y
		local playHeight = if panelHeight > 0 then play.AbsoluteSize.Y / panelHeight else 0
		local top = menu.playY + playHeight + menu.soonGap
		settings.Position = UDim2.fromScale(menu.buttonsX, top)
		shop.Position = UDim2.fromScale(menu.buttonsX, top + menu.soonSize[2] + menu.soonGap)
	end
	play:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeTiles)
	panel:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeTiles)

	makeHowToCard(panel)

	-- Leave sits outside the panel: it shows in the lobby, when the menu is hidden, under the
	-- lobby panel (D-13).
	local lobby = Config.Lobby
	local leave = makeArtButton(
		"Leave",
		Config.Assets.Images.leave,
		"Leave",
		menu.leaveRgb,
		lobby.leaveAspect
	)
	leave.Position =
		UDim2.fromScale(lobby.margin, lobby.centerY + lobby.panelSize[2] / 2 + lobby.margin)
	leave.Size = UDim2.fromScale(lobby.leaveWidth, 1)
	leave.Parent = screenGui

	screenGui.Parent = player:WaitForChild("PlayerGui")
	placeTiles()
	return { panel = panel, play = play, leave = leave }
end

-- Circles the camera around the arena while the menu is up.
local function startOrbit()
	if orbitConnection then
		return
	end
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	orbitStartedAt = os.clock()
	local origin = Config.Arena.origin
	local center = Vector3.new(origin[1], origin[2], origin[3])
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
