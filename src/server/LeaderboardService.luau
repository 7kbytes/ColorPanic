--!strict
-- The all-time top players board in the lobby (A-04).
--
-- Wins go into an OrderedDataStore keyed by user id, which is the only way to ask Roblox
-- for "the highest N" across every server. The board itself is built at runtime from
-- Config, the same way PropCollision adds its colliders, so models/Lobby.rbxm does not have
-- to be regenerated in Studio.
--
-- The server fills the board's labels directly. There is no remote and no client
-- controller, because nothing here is a player decision: it is world content, like the
-- arena tiles.
--
-- If the DataStore cannot be reached, which is the normal case in Studio without API
-- Services, the board says so and the game plays on. Same rule as DataService.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local LeaderboardRules = require(ReplicatedStorage.Shared.LeaderboardRules)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)

type Entry = LeaderboardRules.Entry
type Row = LeaderboardRules.Row

local BOARD = Config.Leaderboard

local LeaderboardService = {}

local started = false
local store: OrderedDataStore? = nil
-- What we last wrote for each player, so an unchanged total is not written again.
local written: { [number]: number } = {}
-- User id to name. Resolving a name is a web call, and the same ten names come back on
-- every refresh, so they are kept.
local names: { [number]: string } = {}

local rowLabels: { { left: TextLabel, right: TextLabel } } = {}
local statusLabel: TextLabel? = nil

local function toColor3(rgb: { number }): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

-- Building the board ---------------------------------------------------------------------

-- Finds the lobby model, which is where the board hangs. Returns nil if the place was
-- synced without the models, which is not an error: the game still plays.
local function lobbyModel(): Instance?
	return workspace:FindFirstChild("Lobby")
end

local function buildBoard(parent: Instance)
	local origin = Config.Placement.lobbyOrigin
	local part = Instance.new("Part")
	part.Name = "LeaderboardBoard"
	part.Anchored = true
	part.CanCollide = true
	part.CanTouch = false
	part.CanQuery = false
	part.Size = Vector3.new(BOARD.size[1], BOARD.size[2], BOARD.thickness)
	part.Color = toColor3(BOARD.backdropRgb)
	part.Transparency = BOARD.backdropTransparency
	part.Material = Enum.Material.SmoothPlastic
	part.CFrame = CFrame.new(
		origin[1] + BOARD.offset[1],
		origin[2] + BOARD.offset[2],
		origin[3] + BOARD.offset[3]
	) * CFrame.Angles(0, math.rad(BOARD.yaw), 0)
	part.Parent = parent

	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 50
	surface.Parent = part

	local padding = Instance.new("Frame")
	padding.Size = UDim2.fromScale(0.9, 0.9)
	padding.Position = UDim2.fromScale(0.05, 0.05)
	padding.BackgroundTransparency = 1
	padding.Parent = surface

	local function label(parentFrame: Instance, scaleY: number, y: number): TextLabel
		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Size = UDim2.fromScale(1, scaleY)
		text.Position = UDim2.fromScale(0, y)
		text.TextColor3 = toColor3(BOARD.textRgb)
		text.TextScaled = true
		text.Font = Enum.Font.BuilderSansBold
		text.TextXAlignment = Enum.TextXAlignment.Left
		text.Text = ""
		text.Parent = parentFrame
		return text
	end

	local title = label(padding, 0.14, 0)
	title.Text = BOARD.title
	title.TextColor3 = toColor3(BOARD.titleRgb)
	title.TextXAlignment = Enum.TextXAlignment.Center

	-- One line per place, laid out under the title.
	local rowHeight = 0.86 / BOARD.topCount
	for index = 1, BOARD.topCount do
		local y = 0.14 + (index - 1) * rowHeight
		local left = label(padding, rowHeight, y)
		local right = label(padding, rowHeight, y)
		right.TextXAlignment = Enum.TextXAlignment.Right
		table.insert(rowLabels, { left = left, right = right })
	end

	-- Sits over the rows for "no winners yet" and for the offline message.
	local status = label(padding, 0.2, 0.4)
	status.TextXAlignment = Enum.TextXAlignment.Center
	status.Visible = false
	statusLabel = status
end

-- The last thing sent to clients, so a player who joins later sees the board straight away
-- instead of waiting for the next refresh.
local lastPayload: Types.LeaderboardPayload = { rows = {}, offline = true }

local function broadcast(rows: { Row }, offline: boolean)
	lastPayload = { rows = rows, offline = offline }
	Remotes.LeaderboardUpdated.fireAll(lastPayload)
end

local function showStatus(message: string)
	for _, row in rowLabels do
		row.left.Text = ""
		row.right.Text = ""
	end
	if statusLabel then
		statusLabel.Text = message
		statusLabel.Visible = true
	end
end

-- The store could not be reached. Clients are told as well, so the menu panel can say so
-- rather than looking like nobody has ever won.
local function showOffline()
	broadcast({}, true)
	showStatus(BOARD.offlineMessage)
end

local function showRows(rows: { Row })
	broadcast(rows, false)
	if #rows == 0 then
		showStatus(BOARD.emptyMessage)
		return
	end
	if statusLabel then
		statusLabel.Visible = false
	end
	for index, labels in rowLabels do
		local row = rows[index]
		if row then
			local left, right = LeaderboardRules.rowText(row, BOARD.maxNameLength)
			labels.left.Text = left
			labels.right.Text = right
		else
			labels.left.Text = ""
			labels.right.Text = ""
		end
	end
end

-- Reading and writing ----------------------------------------------------------------

-- The display name for a user id, cached. Returns "" if Roblox will not say, which
-- LeaderboardRules.usable then drops: a board showing "Player 12345" looks broken.
local function nameFor(userId: number): string
	local cached = names[userId]
	if cached then
		return cached
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local resolved = if ok and type(name) == "string" then name else ""
	if resolved ~= "" then
		names[userId] = resolved
	end
	return resolved
end

local function refresh()
	local activeStore = store
	if not activeStore then
		showOffline()
		return
	end

	local ok, pages = pcall(function()
		return activeStore:GetSortedAsync(false, BOARD.topCount)
	end)
	if not ok or not pages then
		warn(string.format("[Leaderboard] could not read the top players: %s", tostring(pages)))
		showOffline()
		return
	end

	local okPage, page = pcall(function()
		return pages:GetCurrentPage()
	end)
	if not okPage or not page then
		warn("[Leaderboard] the sorted page could not be read")
		showOffline()
		return
	end

	local entries: { Entry } = {}
	for _, item in page do
		local userId = tonumber(item.key)
		local wins = tonumber(item.value)
		if userId and wins then
			table.insert(entries, { userId = userId, name = nameFor(userId), wins = wins })
		end
	end

	showRows(LeaderboardRules.rank(LeaderboardRules.usable(entries), BOARD.topCount))
end

-- Records a player's new all-time win total. Called when a match is won, not every round,
-- so the write budget stays small.
function LeaderboardService.recordWins(player: Player, totalWins: number)
	local activeStore = store
	if not activeStore then
		return
	end
	if not LeaderboardRules.needsWrite(written[player.UserId], totalWins) then
		return
	end
	local userId = player.UserId
	task.spawn(function()
		local ok, err = pcall(function()
			activeStore:SetAsync(tostring(userId), totalWins)
		end)
		if ok then
			written[userId] = totalWins
		else
			-- Left out of `written` on purpose, so the next win tries again.
			warn(string.format("[Leaderboard] could not save %s: %s", player.Name, tostring(err)))
		end
	end)
end

function LeaderboardService.start()
	assert(not started, "LeaderboardService.start() called twice")
	started = true

	local lobby = lobbyModel()
	if not lobby then
		print("[Leaderboard] no Lobby model in the workspace, skipping the board")
		return
	end
	buildBoard(lobby)

	local ok, opened = pcall(function()
		return DataStoreService:GetOrderedDataStore(BOARD.storeKey)
	end)
	if ok and opened then
		store = opened
	else
		warn(string.format("[Leaderboard] store unavailable (%s)", tostring(opened)))
		showOffline()
		return
	end

	-- A player who joins between refreshes gets what the board is showing now, rather than
	-- an empty panel until the next one.
	Players.PlayerAdded:Connect(function(player: Player)
		Remotes.LeaderboardUpdated.fireTo(player, lastPayload)
	end)

	task.spawn(function()
		while true do
			refresh()
			task.wait(BOARD.refreshSeconds)
		end
	end)
end

return LeaderboardService
