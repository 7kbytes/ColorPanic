--!strict
-- Player settings (A-07): music and sound effect volume.
--
-- Volumes are stored as whole percentages, 0 to 100, which multiply the mix in
-- Config.Audio. Percentages keep the saved profile to integers, which is what the
-- DataStore sanitizer already guarantees, and they are what the panel shows.
--
-- Pure, so it is tested outside Studio.

local SettingsRules = {}

local MIN = 0
local MAX = 100

-- Forces anything at all into a usable percentage.
--
-- This runs on values that came off the DataStore and on values that came from a client,
-- so it has to cope with nil, text, NaN, a negative, and 10000.
function SettingsRules.clampPercent(value: any): number
	if type(value) ~= "number" or value ~= value then
		return MAX -- nil, text or NaN: full volume, the same as a new player
	end
	return math.clamp(math.floor(value), MIN, MAX)
end

-- The percentage after a step up or down, kept on the step grid and inside range.
function SettingsRules.step(percent: number, delta: number, stepSize: number): number
	local current = SettingsRules.clampPercent(percent)
	local size = math.max(1, math.floor(stepSize))
	return SettingsRules.clampPercent(current + delta * size)
end

-- The 0 to 1 multiplier for a percentage, for Roblox's Volume.
function SettingsRules.scale(percent: number): number
	return SettingsRules.clampPercent(percent) / MAX
end

-- What the panel shows next to a row.
function SettingsRules.label(percent: number): string
	local value = SettingsRules.clampPercent(percent)
	if value <= MIN then
		return "Off"
	end
	return string.format("%d%%", value)
end

-- Whether a request from a client is worth acting on.
--
-- The client sends a whole settings table. Anything that is not a table is dropped; the
-- values inside are clamped rather than rejected, since a client sending 150 means the
-- same thing as 100 and there is nothing to gain by refusing it.
function SettingsRules.readRequest(payload: any): { music: number, sfx: number }?
	if type(payload) ~= "table" then
		return nil
	end
	return {
		music = SettingsRules.clampPercent(payload.music),
		sfx = SettingsRules.clampPercent(payload.sfx),
	}
end

-- Whether the settings actually changed, so an unchanged request is not saved.
function SettingsRules.changed(
	currentMusic: number,
	currentSfx: number,
	nextMusic: number,
	nextSfx: number
): boolean
	return SettingsRules.clampPercent(currentMusic) ~= SettingsRules.clampPercent(nextMusic)
		or SettingsRules.clampPercent(currentSfx) ~= SettingsRules.clampPercent(nextSfx)
end

return SettingsRules
