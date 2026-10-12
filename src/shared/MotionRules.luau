--!strict
-- The decisions behind the feel pass (A-09), kept pure so they can be tested without Roblox.
-- Everything here answers one question: how strong should the glow on a matching tile be
-- right now? The drawing itself is in client/TileGlow.

local MotionRules = {}

-- How visible the glow on a matching tile should be, from 0 (nothing) to 1 (full strength).
--
-- `revealUntil` is the server time the target hides, and is nil in rounds that keep the target
-- on screen for the whole round: those glow at full strength. In a reveal-then-hide round the
-- glow fades out over the last `fadeSeconds` of the reveal and is gone by the time the target
-- hides, so it never survives into the part of the round players are meant to remember.
function MotionRules.glowAlpha(now: number, revealUntil: number?, fadeSeconds: number): number
	if revealUntil == nil then
		return 1
	end
	local remaining = revealUntil - now
	if remaining <= 0 then
		return 0
	end
	if fadeSeconds <= 0 or remaining >= fadeSeconds then
		return 1
	end
	return remaining / fadeSeconds
end

-- Turns an alpha from glowAlpha into a Roblox transparency, where 0 is solid and 1 invisible.
-- `transparencyAtFull` is how transparent the glow is at full strength, from Config.
function MotionRules.transparency(alpha: number, transparencyAtFull: number): number
	local clamped = math.clamp(alpha, 0, 1)
	return transparencyAtFull + (1 - transparencyAtFull) * (1 - clamped)
end

return MotionRules
