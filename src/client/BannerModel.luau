--!strict
-- The big centre banner (D-12): "Match starting" during Intermission and the round intro during
-- RoundIntro. Kept pure so it can be tested outside Studio. Everything comes from the HudModel,
-- which only holds what the server sent; the banner shows and hides with the server's states.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(ReplicatedStorage.Shared.Util)
local HudModel = require(script.Parent.HudModel)

-- Intermission: the match countdown. Round: a normal round intro. Final: the last round of a
-- capped match. Replay: the round is played again because everyone fell.
export type Kind = "Intermission" | "Round" | "Final" | "Replay"

export type Banner = {
	kind: Kind,
	title: string,
	subtitle: string,
}

local BannerModel = {}

-- "12" for whole seconds, "6.5" otherwise.
local function formatSeconds(seconds: number): string
	return string.format("%g", seconds)
end

-- The intro subtitle: what this round asks of the player.
-- The target the intro asks for ("Find the Red Heart"), with the Run timer. Reveal rounds keep
-- the target secret until Run, so they ask players to memorize it instead.
local function roundSubtitle(model: HudModel.Model, now: number): string
	if model.revealSeconds then
		return "Memorize the color!"
	end
	local timer = model.timerSeconds
	local target = HudModel.targetView(model, now)
	local colorDef = if target.colorId then Util.getColorDef(Config.Colors, target.colorId) else nil
	if colorDef and timer then
		return string.format(
			"Find the %s · %s seconds",
			Util.displayName(colorDef),
			formatSeconds(timer)
		)
	end
	local colors = model.colorCount
	if colors and timer then
		return string.format("%d colors · %s seconds", colors, formatSeconds(timer))
	end
	return ""
end

-- The banner to show at server time `now`, or nil for none.
function BannerModel.view(model: HudModel.Model, now: number): Banner?
	local state = model.state
	if state == "Intermission" then
		local endsAt = model.endsAt
		local countdown = if endsAt then tostring(math.ceil(math.max(0, endsAt - now))) else ""
		return { kind = "Intermission", title = "Match starting", subtitle = countdown }
	end

	local round = model.round
	if state ~= "RoundIntro" or round == nil then
		return nil
	end
	if model.isReplay then
		return {
			kind = "Replay",
			title = "Everyone fell!",
			subtitle = string.format("Round %d again", round),
		}
	end
	if round >= Config.Match.maxRounds then
		return { kind = "Final", title = "Final round!", subtitle = roundSubtitle(model, now) }
	end
	return {
		kind = "Round",
		title = string.format("Round %d", round),
		subtitle = roundSubtitle(model, now),
	}
end

return BannerModel
