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

local function makeButton(name: string, text: string, rgb: { number }): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.Text = text
	button.TextScaled = true
	button.Font = Enum.Font.BuilderSansBold
	button.TextColor3 = toColor3(Config.Menu.textRgb)
	button.BackgroundColor3 = toColor3(rgb)
	button.AutoButtonColor = true
	addCorner(button)
	addTextLimit(button)
	return button
end

-- Leave (D-13): the red "Back" button art under the lobby panel. If the art is not uploaded (ID
-- 0) or fails to load, a plain red button with the word Leave stands in.
local function makeLeaveButton(): ImageButton
	local lobby = Config.Lobby
	local leave = Instance.new("ImageButton")
	leave.Name = "Leave"
	leave.BackgroundTransparency = 1
	leave.BackgroundColor3 = toColor3(Config.Menu.leaveRgb)
	leave.ScaleType = Enum.ScaleType.Fit
	leave.Position =
		UDim2.fromScale(lobby.margin, lobby.centerY + lobby.panelSize[2] / 2 + lobby.margin)
	leave.Size = UDim2.fromScale(lobby.leaveWidth, 1)
	local aspect = Instance.new("UIAspectRatioConstraint")
	aspect.AspectRatio = lobby.leaveAspect
	aspect.DominantAxis = Enum.DominantAxis.Width
	aspect.Parent = leave

	local fallback = Instance.new("TextLabel")
	fallback.Name = "Fallback"
	fallback.Text = "Leave"
	fallback.TextScaled = true
	fallback.Font = Enum.Font.BuilderSansBold
	fallback.TextColor3 = toColor3(Config.Menu.textRgb)
	fallback.BackgroundTransparency = 1
	fallback.Size = UDim2.fromScale(1, 1)
	fallback.Visible = false
	addTextLimit(fallback)
	fallback.Parent = leave

	local function useFallback()
		leave.Image = ""
		leave.BackgroundTransparency = 0
		addCorner(leave)
		fallback.Visible = true
	end
	local id = Config.Assets.Images.leave
	if id == 0 then
		useFallback()
	else
		leave.Image = "rbxassetid://" .. tostring(id)
		task.spawn(function()
			ContentProvider:PreloadAsync({ leave }, function(_, status)
				if status ~= Enum.AssetFetchStatus.Success then
					warn(
						string.format("[Menu] Leave art %d did not load (%s)", id, tostring(status))
					)
					useFallback()
				end
			end)
		end)
	end
	return leave
end

type Gui = { panel: Frame, play: TextButton, leave: ImageButton }

local function buildGui(): Gui
	local menu = Config.Menu
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "Menu"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = MENU_DISPLAY_ORDER
	screenGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets

	-- The menu: a dimmed backdrop over the live match, a title and a big Play button.
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.fromScale(1, 1)
	panel.BackgroundColor3 = toColor3(menu.backdropRgb)
	panel.BackgroundTransparency = menu.backdropTransparency
	panel.BorderSizePixel = 0
	panel.Parent = screenGui

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Text = "Color Panic"
	title.TextScaled = true
	title.Font = Enum.Font.BuilderSansBold
	title.TextColor3 = toColor3(menu.textRgb)
	title.BackgroundTransparency = 1
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.fromScale(0.5, menu.titleY)
	title.Size = UDim2.fromScale(menu.titleSize[1], menu.titleSize[2])
	addTextLimit(title)
	title.Parent = panel

	local play = makeButton("Play", "Play", menu.buttonRgb)
	play.AnchorPoint = Vector2.new(0.5, 0.5)
	play.Position = UDim2.fromScale(0.5, menu.playY)
	play.Size = UDim2.fromScale(menu.playSize[1], menu.playSize[2])
	play.Parent = panel

	-- Leave sits outside the panel: it shows in the lobby, when the menu is hidden.
	local leave = makeLeaveButton()
	leave.Parent = screenGui

	screenGui.Parent = player:WaitForChild("PlayerGui")
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
