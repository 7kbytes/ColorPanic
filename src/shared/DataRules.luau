--!strict
-- Pure rules for player profiles, rewards and progression.
-- Kept pure so it can be tested outside Studio with Lune.

local SettingsRules = require(script.Parent.SettingsRules)
local Types = require(script.Parent.Types)

type PlayerProfile = Types.PlayerProfile

local DataRules = {}

-- Returns a fresh default profile for a new player.
function DataRules.defaultProfile(): PlayerProfile
	return {
		wins = 0,
		roundsSurvived = 0,
		matchesPlayed = 0,
		coins = 0,
		lastClaimDay = 0,
		streak = 0,
		musicPercent = 100,
		sfxPercent = 100,
	}
end

-- Sanitizes raw loaded data from DataStore into a valid PlayerProfile.
-- Clamps numbers to non-negative integers and supplies defaults for any missing keys.
function DataRules.sanitize(raw: any): PlayerProfile
	local default = DataRules.defaultProfile()
	if type(raw) ~= "table" then
		return default
	end

	local function sanitizeInt(val: any, fallback: number): number
		if type(val) == "number" and val == val and val >= 0 then
			return math.floor(val)
		end
		return fallback
	end

	return {
		wins = sanitizeInt(raw.wins, default.wins),
		roundsSurvived = sanitizeInt(raw.roundsSurvived, default.roundsSurvived),
		matchesPlayed = sanitizeInt(raw.matchesPlayed, default.matchesPlayed),
		coins = sanitizeInt(raw.coins, default.coins),
		lastClaimDay = sanitizeInt(raw.lastClaimDay, default.lastClaimDay),
		streak = sanitizeInt(raw.streak, default.streak),
		-- Volumes are a percentage, so they are capped as well as floored. A stored 0 is
		-- a deliberate mute and must survive loading.
		musicPercent = SettingsRules.clampPercent(raw.musicPercent),
		sfxPercent = SettingsRules.clampPercent(raw.sfxPercent),
	}
end

-- Grants rewards for surviving a round. Returns a cloned and updated profile.
function DataRules.recordRoundSurvived(profile: PlayerProfile, coinsEarned: number): PlayerProfile
	local coins = math.max(0, math.floor(coinsEarned))
	return {
		wins = profile.wins,
		roundsSurvived = profile.roundsSurvived + 1,
		matchesPlayed = profile.matchesPlayed,
		coins = profile.coins + coins,
		lastClaimDay = profile.lastClaimDay,
		streak = profile.streak,
		musicPercent = profile.musicPercent,
		sfxPercent = profile.sfxPercent,
	}
end

-- Grants rewards for winning a match. Returns a cloned and updated profile.
function DataRules.recordMatchVictory(profile: PlayerProfile, coinsEarned: number): PlayerProfile
	local coins = math.max(0, math.floor(coinsEarned))
	return {
		wins = profile.wins + 1,
		roundsSurvived = profile.roundsSurvived,
		matchesPlayed = profile.matchesPlayed,
		coins = profile.coins + coins,
		lastClaimDay = profile.lastClaimDay,
		streak = profile.streak,
		musicPercent = profile.musicPercent,
		sfxPercent = profile.sfxPercent,
	}
end

-- Records that the player completed a match. Returns a cloned and updated profile.
function DataRules.recordMatchPlayed(profile: PlayerProfile): PlayerProfile
	return {
		wins = profile.wins,
		roundsSurvived = profile.roundsSurvived,
		matchesPlayed = profile.matchesPlayed + 1,
		coins = profile.coins,
		lastClaimDay = profile.lastClaimDay,
		streak = profile.streak,
		musicPercent = profile.musicPercent,
		sfxPercent = profile.sfxPercent,
	}
end

-- Checks if the profile has at least cost coins.
function DataRules.canAfford(profile: PlayerProfile, cost: number): boolean
	return cost >= 0 and profile.coins >= math.floor(cost)
end

-- Deducts amount coins if affordable. Returns success and the updated profile.
function DataRules.deductCoins(profile: PlayerProfile, amount: number): (boolean, PlayerProfile)
	local cost = math.floor(amount)
	if cost < 0 or profile.coins < cost then
		return false, table.clone(profile)
	end
	return true,
		{
			wins = profile.wins,
			roundsSurvived = profile.roundsSurvived,
			matchesPlayed = profile.matchesPlayed,
			coins = profile.coins - cost,
			lastClaimDay = profile.lastClaimDay,
			streak = profile.streak,
			musicPercent = profile.musicPercent,
			sfxPercent = profile.sfxPercent,
		}
end

-- Copies every saved field of `profile` into the existing table `target`, and returns it.
--
-- The rest of this module returns new profile tables, which keeps the rules easy to reason
-- about. ProfileStore, though, saves one specific table (`Profile.Data`) and does not notice
-- a replacement, so updates have to be written into that table in place. This is the one
-- place that does it.
function DataRules.copyInto(target: PlayerProfile, profile: PlayerProfile): PlayerProfile
	target.wins = profile.wins
	target.roundsSurvived = profile.roundsSurvived
	target.matchesPlayed = profile.matchesPlayed
	target.coins = profile.coins
	target.lastClaimDay = profile.lastClaimDay
	target.streak = profile.streak
	target.musicPercent = profile.musicPercent
	target.sfxPercent = profile.sfxPercent
	return target
end

-- A short string that changes whenever any saved field changes.
--
-- H-01 added this so DataService could skip writing an unchanged profile. ProfileStore now
-- decides when to write, so nothing in the game calls it; it is kept because it is the one
-- cheap way to compare two profiles in tests and in logs.
function DataRules.signature(profile: PlayerProfile): string
	return string.format(
		"%d|%d|%d|%d|%d|%d|%d|%d",
		profile.wins,
		profile.roundsSurvived,
		profile.matchesPlayed,
		profile.coins,
		profile.lastClaimDay,
		profile.streak,
		profile.musicPercent,
		profile.sfxPercent
	)
end

return DataRules
