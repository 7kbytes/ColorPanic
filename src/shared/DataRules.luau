--!strict
-- Pure rules for player profiles, rewards and progression.
-- Kept pure so it can be tested outside Studio with Lune.

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
	}
end

-- Records that the player completed a match. Returns a cloned and updated profile.
function DataRules.recordMatchPlayed(profile: PlayerProfile): PlayerProfile
	return {
		wins = profile.wins,
		roundsSurvived = profile.roundsSurvived,
		matchesPlayed = profile.matchesPlayed + 1,
		coins = profile.coins,
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
		}
end

return DataRules
