--!strict
-- The wins nameplate over every player's head (A-12). Shows leaderstats.Wins, which
-- DataService owns and Roblox replicates, so this only draws: it never counts a win and can
-- never disagree with the results panel or the lobby board.
--
-- Built on the client, for every player including the local one, because it is rendering.
-- That also means a tag follows its player through a respawn without the server doing
-- anything: a new character means a new head, so the tag is rebuilt on CharacterAdded.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local UiStyle = require(script.Parent.UiStyle)

local TAG = Config.WinsTag
local HUD = Config.Hud
local TAG_NAME = "WinsTag"

local WinsTag = {}

local started = false

-- Builds the billboard on a head, or returns the one already there. Parented to the head, so
-- it dies with the character and nothing has to be cleaned up on respawn or on leaving.
local function billboardFor(head: BasePart): (BillboardGui, TextLabel)
	local existing = head:FindFirstChild(TAG_NAME)
	if existing and existing:IsA("BillboardGui") then
		local label = existing:FindFirstChildOfClass("TextLabel")
		if label then
			return existing, label
		end
		existing:Destroy()
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = TAG_NAME
	billboard.Size = UDim2.fromOffset(TAG.sizePixels[1], TAG.sizePixels[2])
	billboard.StudsOffsetWorldSpace = Vector3.new(0, TAG.studsAboveHead, 0)
	billboard.MaxDistance = TAG.maxDistanceStuds
	-- Drawn behind the arena rather than through it, so a tag cannot point out a player
	-- hiding behind a tile and give their position away.
	billboard.AlwaysOnTop = false
	billboard.LightInfluence = 0 -- keeps the text readable under the arena's lighting
	billboard.ResetOnSpawn = false

	local label = Instance.new("TextLabel")
	label.Name = "Wins"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = UiStyle.HEADING_FONT
	label.TextColor3 = UiStyle.toColor3(HUD.textRgb)
	label.TextSize = TAG.textSize
	label.TextScaled = false
	label.Text = ""
	label.Parent = billboard

	local stroke = Instance.new("UIStroke")
	stroke.Color = UiStyle.toColor3(HUD.strokeRgb)
	stroke.Thickness = HUD.strokeThickness
	stroke.Parent = label

	billboard.Parent = head
	return billboard, label
end

-- Draws `wins` over `head`, or takes the tag away when there is nothing to say.
local function draw(head: BasePart, wins: number)
	local text = Util.winsLabel(wins, TAG)
	if not text then
		local existing = head:FindFirstChild(TAG_NAME)
		if existing then
			existing:Destroy()
		end
		return
	end
	local _, label = billboardFor(head)
	label.Text = text
end

-- Follows one player: their wins, and whichever character they currently have.
--
-- Everything here waits rather than looks, because all three parts arrive in their own time
-- and in no fixed order: the player, the leaderstats folder the server builds for them, the
-- Wins value inside it, and the character. An earlier version looked for Wins the moment the
-- leaderstats folder appeared, found an empty folder, and gave up for good.
local function watch(player: Player)
	task.spawn(function()
		local stats = player:WaitForChild("leaderstats", 30)
		if not stats then
			-- No leaderstats at all means the server is running without saved data, so
			-- there is no win count to show and the tag stays off.
			return
		end
		local wins = stats:WaitForChild("Wins", 10)
		if not wins or not wins:IsA("IntValue") then
			return
		end

		local function drawOn(character: Model?)
			if not character then
				return
			end
			local head = character:FindFirstChild("Head") or character:WaitForChild("Head", 10)
			if head and head:IsA("BasePart") then
				draw(head, wins.Value)
			end
		end

		wins:GetPropertyChangedSignal("Value"):Connect(function()
			drawOn(player.Character)
		end)
		player.CharacterAdded:Connect(function(character)
			drawOn(character)
		end)
		drawOn(player.Character)
	end)
end

function WinsTag.start()
	if started or not TAG.enabled then
		return
	end
	started = true
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
end

return WinsTag
