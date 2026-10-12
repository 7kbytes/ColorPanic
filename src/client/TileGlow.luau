--!strict
-- Glows the tiles that match the current target (A-09), so the mechanic reads at a glance on
-- a phone. A Highlight is parented to each matching tile while the target is on screen, and
-- fades out as a reveal-then-hide round's reveal runs down (MotionRules.glowAlpha). Nothing
-- here decides anything about the match: HUDController passes in the target card the HUD is
-- already drawing, so the glow and the card can never disagree.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local MotionRules = require(ReplicatedStorage.Shared.MotionRules)
local UiStyle = require(script.Parent.UiStyle)

local ARENA = Config.Arena
local GLOW = Config.Motion.Glow
local HIGHLIGHT_NAME = "TargetGlow"

local TileGlow = {}

local fillColor = UiStyle.toColor3(GLOW.fillRgb)
local outlineColor = UiStyle.toColor3(GLOW.outlineRgb)

-- The tiles folder, or nil before the server has built the arena.
local function tilesFolder(): Instance?
	local arena = workspace:FindFirstChild(ARENA.folderName)
	return if arena then arena:FindFirstChild(ARENA.tilesFolderName) else nil
end

-- The Highlight on a tile, created on first use. It is a child of the tile, so it is
-- destroyed with it when the arena is rebuilt and never needs cleaning up separately.
local function highlightFor(tile: BasePart): Highlight
	local existing = tile:FindFirstChild(HIGHLIGHT_NAME)
	if existing and existing:IsA("Highlight") then
		return existing
	end
	local highlight = Instance.new("Highlight")
	highlight.Name = HIGHLIGHT_NAME
	highlight.Adornee = tile
	highlight.FillColor = fillColor
	highlight.OutlineColor = outlineColor
	-- Occluded: the glow should not shine through the arena at a player below it.
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.FillTransparency = 1
	highlight.OutlineTransparency = 1
	highlight.Parent = tile
	return highlight
end

-- Draws the glow for this frame. `colorId` is the target's palette id, or nil when there is
-- no target to show (no round yet, or a hidden target): then nothing glows. `revealUntil` is
-- the server time the target hides, nil in rounds that never hide it.
function TileGlow.update(colorId: number?, revealUntil: number?, now: number)
	if not Config.Motion.enabled then
		return
	end
	local folder = tilesFolder()
	if not folder then
		return
	end
	local alpha = if colorId then MotionRules.glowAlpha(now, revealUntil, GLOW.fadeSeconds) else 0
	local fill = MotionRules.transparency(alpha, GLOW.fillTransparency)
	local outline = MotionRules.transparency(alpha, GLOW.outlineTransparency)
	for _, tile in folder:GetChildren() do
		if not tile:IsA("BasePart") then
			continue
		end
		local matches = colorId ~= nil and tile:GetAttribute(ARENA.colorAttribute) == colorId
		-- A tile that has never glowed and does not match now needs no Highlight at all.
		local existing = tile:FindFirstChild(HIGHLIGHT_NAME)
		if not matches and not existing then
			continue
		end
		local highlight = highlightFor(tile)
		highlight.FillTransparency = if matches then fill else 1
		highlight.OutlineTransparency = if matches then outline else 1
	end
end

return TileGlow
