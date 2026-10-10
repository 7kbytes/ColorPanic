--!strict
-- Eliminated card and watch-only spectating (D-14).
-- When the server eliminates the local player, a card says so and offers Spectate. Spectating
-- points the local camera at a survivor (Camera.CameraSubject) and shows a bar to switch
-- between survivors or stop. Players who joined mid-match get a Spectate button too.
-- Everything here is local: who is a survivor comes from the server's MatchRole attribute, and
-- watching never sends anything to the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)
local SpectateModel = require(script.Parent.SpectateModel)
local UiStyle = require(script.Parent.UiStyle)

local MATCH_ROLE_ATTRIBUTE = "MatchRole"
-- Above the HUD (0), under the menu (10).
local DISPLAY_ORDER = 5
-- States that end spectating and close the card: the match is over.
local MATCH_OVER: { [Types.MatchState]: boolean } = {
	Reset = true,
	Lobby = true,
	Intermission = true,
}

local SPECTATE = Config.Spectate
local toColor3 = UiStyle.toColor3

local SpectateController = {}

local started = false
local player = Players.LocalPlayer

type Gui = {
	screenGui: ScreenGui,
	dim: Frame,
	cardTitle: TextLabel,
	cardSubtitle: TextLabel,
	cardSpectate: TextButton,
	cardClose: TextButton,
	bar: Frame,
	barName: TextLabel,
	barPrevious: TextButton,
	barNext: TextButton,
	barStop: TextButton,
	joinerSpectate: TextButton,
}

local function makeImage(name: string, id: number, parent: Instance): ImageLabel
	local image = Instance.new("ImageLabel")
	image.Name = name
	image.BackgroundTransparency = 1
	image.ScaleType = Enum.ScaleType.Fit
	-- Decorative: the text beside it carries the meaning, so a missing image leaves no gap.
	image.Image = if id ~= 0 then UiStyle.assetUrl(id) else ""
	image.Parent = parent
	return image
end

local function buildGui(): Gui
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "Spectate"
	screenGui.ResetOnSpawn = false
	screenGui.DisplayOrder = DISPLAY_ORDER
	screenGui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets

	-- Eliminated card: a dimmed backdrop, then the sad face, title, subtitle and two buttons.
	local dim = Instance.new("Frame")
	dim.Name = "Dim"
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = toColor3(SPECTATE.dimRgb)
	dim.BackgroundTransparency = SPECTATE.dimTransparency
	dim.BorderSizePixel = 0
	dim.Visible = false
	dim.Parent = screenGui

	local card = UiStyle.makePanel(
		"Card",
		SPECTATE.cardSize,
		Vector2.new(0.5, 0.5),
		UDim2.fromScale(0.5, 0.5)
	)
	card.Visible = true
	card.Parent = dim
	local face = makeImage("SadFace", Config.Assets.Images.sadFace, card)
	face.AnchorPoint = Vector2.new(0.5, 0)
	face.Position = UDim2.fromScale(0.5, 0)
	face.Size = UDim2.fromScale(1, 0.3)
	local cardTitle =
		UiStyle.makeText("Title", card, UiStyle.HEADING_FONT, Config.Banner.maxTitleSize)
	cardTitle.Position = UDim2.fromScale(0, 0.31)
	cardTitle.Size = UDim2.fromScale(1, 0.22)
	local cardSubtitle =
		UiStyle.makeText("Subtitle", card, UiStyle.BODY_FONT, Config.Banner.maxSubtitleSize)
	cardSubtitle.Position = UDim2.fromScale(0, 0.53)
	cardSubtitle.Size = UDim2.fromScale(1, 0.14)
	local cardSpectate = UiStyle.makeButton("Spectate", "Spectate", SPECTATE.buttonRgb)
	cardSpectate.Position = UDim2.fromScale(0.08, 0.72)
	cardSpectate.Size = UDim2.fromScale(0.55, 0.26)
	cardSpectate.Parent = card
	local cardClose = UiStyle.makeButton("Close", "Close", SPECTATE.quietButtonRgb)
	cardClose.Position = UDim2.fromScale(0.67, 0.72)
	cardClose.Size = UDim2.fromScale(0.25, 0.26)
	cardClose.Parent = card

	-- Spectate bar: previous, eye and "Watching <name>", next, stop.
	local bar = UiStyle.makePanel(
		"WatchBar",
		SPECTATE.barSize,
		Vector2.new(0.5, 1),
		UDim2.fromScale(0.5, 1 - SPECTATE.barBottom)
	)
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, Config.Hud.padding)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = bar
	local barPrevious = UiStyle.makeButton("Previous", "<", SPECTATE.quietButtonRgb)
	barPrevious.LayoutOrder = 1
	barPrevious.Size = UDim2.fromScale(0.12, 1)
	barPrevious.Parent = bar
	local eye = makeImage("Eye", Config.Assets.Images.eye, bar)
	eye.LayoutOrder = 2
	eye.Size = UDim2.fromScale(0.1, 1)
	local barName = UiStyle.makeText("Watching", bar, UiStyle.BODY_FONT)
	barName.LayoutOrder = 3
	barName.Size = UDim2.fromScale(0.42, 1)
	local barNext = UiStyle.makeButton("Next", ">", SPECTATE.quietButtonRgb)
	barNext.LayoutOrder = 4
	barNext.Size = UDim2.fromScale(0.12, 1)
	barNext.Parent = bar
	local barStop = UiStyle.makeButton("Stop", "Stop", SPECTATE.quietButtonRgb)
	barStop.LayoutOrder = 5
	barStop.Size = UDim2.fromScale(0.16, 1)
	barStop.Parent = bar
	bar.Parent = screenGui

	-- Spectate for spectators who are not watching (mid-match joiners, or after Close): where
	-- Leave sits in the lobby (Leave is hidden for spectators), under the "Next match" panel.
	local lobby = Config.Lobby
	local joinerSpectate = UiStyle.makeButton("SpectateMatch", "Spectate", SPECTATE.buttonRgb)
	joinerSpectate.Position =
		UDim2.fromScale(lobby.margin, lobby.centerY + lobby.panelSize[2] / 2 + lobby.margin)
	joinerSpectate.Size =
		UDim2.fromScale(SPECTATE.spectateButtonSize[1], SPECTATE.spectateButtonSize[2])
	joinerSpectate.Visible = false
	joinerSpectate.Parent = screenGui

	screenGui.Parent = player:WaitForChild("PlayerGui")
	return {
		screenGui = screenGui,
		dim = dim,
		cardTitle = cardTitle,
		cardSubtitle = cardSubtitle,
		cardSpectate = cardSpectate,
		cardClose = cardClose,
		bar = bar,
		barName = barName,
		barPrevious = barPrevious,
		barNext = barNext,
		barStop = barStop,
		joinerSpectate = joinerSpectate,
	}
end

-- Everyone in the game with the role the server gave them.
local function candidates(): { SpectateModel.Candidate }
	local list: { SpectateModel.Candidate } = {}
	for _, other in Players:GetPlayers() do
		local role = other:GetAttribute(MATCH_ROLE_ATTRIBUTE)
		table.insert(list, {
			userId = other.UserId,
			name = other.DisplayName,
			role = if type(role) == "string" then role else nil,
		})
	end
	return list
end

local function humanoidOf(target: Player?): Humanoid?
	local character = target and target.Character
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

function SpectateController.start()
	assert(not started, "SpectateController.start() called twice")
	started = true

	local gui = buildGui()
	local state: Types.MatchState? = nil
	local round: number? = nil
	local cardOpen = false
	local watching = false
	local watchedId: number? = nil

	local function stopWatching()
		watching = false
		watchedId = nil
		local camera = workspace.CurrentCamera
		local own = humanoidOf(player)
		if own and camera.CameraType == Enum.CameraType.Custom then
			camera.CameraSubject = own
		end
	end

	local function startWatching()
		cardOpen = false
		watching = true
		watchedId = SpectateModel.pick(SpectateModel.targets(candidates(), player.UserId), nil)
	end

	local function step(direction: number)
		watchedId = SpectateModel.step(
			SpectateModel.targets(candidates(), player.UserId),
			watchedId,
			direction
		)
	end

	gui.cardSpectate.Activated:Connect(startWatching)
	gui.cardClose.Activated:Connect(function()
		cardOpen = false
	end)
	gui.joinerSpectate.Activated:Connect(startWatching)
	gui.barStop.Activated:Connect(stopWatching)
	gui.barPrevious.Activated:Connect(function()
		step(-1)
	end)
	gui.barNext.Activated:Connect(function()
		step(1)
	end)

	Remotes.StateChanged.connect(function(payload)
		state = payload.state
		if MATCH_OVER[payload.state] then
			cardOpen = false
			if watching then
				stopWatching()
			end
		end
	end)
	Remotes.RoundInfo.connect(function(payload)
		round = payload.round
	end)
	Remotes.PlayerEliminated.connect(function(payload)
		if payload.userId == player.UserId then
			cardOpen = true
			local card = SpectateModel.card(round)
			gui.cardTitle.Text = card.title
			gui.cardSubtitle.Text = card.subtitle
		end
	end)

	RunService.Heartbeat:Connect(function()
		local role = player:GetAttribute(MATCH_ROLE_ATTRIBUTE)
		local isSpectator = role == "Spectator"
		if watching and not isSpectator then
			stopWatching() -- the match ended or the player went back to the menu
		end

		if watching then
			local targets = SpectateModel.targets(candidates(), player.UserId)
			watchedId = SpectateModel.pick(targets, watchedId)
			local watched = if watchedId then Players:GetPlayerByUserId(watchedId) else nil
			local humanoid = humanoidOf(watched)
			if watched and humanoid then
				local camera = workspace.CurrentCamera
				-- Reapplied every frame: Roblox points the camera back at our own character
				-- when it respawns.
				if camera.CameraSubject ~= humanoid then
					camera.CameraSubject = humanoid
				end
				gui.barName.Text = "Watching " .. watched.DisplayName
				local several = #targets > 1
				gui.barPrevious.Visible = several
				gui.barNext.Visible = several
			elseif watchedId == nil then
				stopWatching() -- nobody left to watch
			end
		end

		gui.dim.Visible = cardOpen and isSpectator
		gui.bar.Visible = watching
		-- Any spectator while a match runs: mid-match joiners, and eliminated players who
		-- closed the card.
		gui.joinerSpectate.Visible = isSpectator
			and not cardOpen
			and not watching
			and state ~= nil
			and not MATCH_OVER[state]
	end)
end

return SpectateController
