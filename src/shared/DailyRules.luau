--!strict
-- Daily rewards (A-08): when a claim is allowed, what it pays, and what it does to the
-- streak. Pure, so it is tested outside Studio.
--
-- Every time here is a server time. The client never decides whether a day has passed:
-- it would only have to change its own clock to claim as often as it liked.

local Types = require(script.Parent.Types)

type PlayerProfile = Types.PlayerProfile

local DailyRules = {}

local SECONDS_PER_DAY = 86400

-- The whole UTC day a server timestamp falls in. Days are counted from the Unix epoch,
-- so the number only ever goes up and two servers always agree on today.
function DailyRules.dayIndex(unixTime: number): number
	return math.floor(unixTime / SECONDS_PER_DAY)
end

-- Seconds until the next day starts, for the countdown on the panel.
function DailyRules.secondsUntilNextDay(unixTime: number): number
	local nextDay = (DailyRules.dayIndex(unixTime) + 1) * SECONDS_PER_DAY
	return math.max(0, nextDay - unixTime)
end

-- Whether this profile may claim today. One claim per day, and never twice in the same
-- day however many times the button is pressed.
function DailyRules.canClaim(profile: PlayerProfile, today: number): boolean
	return profile.lastClaimDay < today
end

-- The streak after claiming on `today`.
--
-- Claiming the day after the last claim continues the streak. Missing a day or more
-- starts again at 1, which is the whole point of a streak. A first claim is also 1.
function DailyRules.nextStreak(profile: PlayerProfile, today: number): number
	if profile.lastClaimDay == today - 1 then
		return profile.streak + 1
	end
	return 1
end

-- Which day of the reward track a streak lands on, counting from 1.
--
-- The track repeats once it runs out, so a player on day 9 of a 7 day track is back on
-- the first reward rather than falling off the end.
function DailyRules.trackDay(streak: number, trackLength: number): number
	if trackLength <= 0 then
		return 0
	end
	local position = math.max(1, math.floor(streak))
	return ((position - 1) % trackLength) + 1
end

-- The coins a streak pays, from the Config track.
function DailyRules.rewardFor(streak: number, track: { number }): number
	local day = DailyRules.trackDay(streak, #track)
	if day == 0 then
		return 0
	end
	return math.max(0, math.floor(track[day]))
end

export type ClaimResult = {
	claimed: boolean,
	profile: PlayerProfile, -- unchanged when the claim was refused
	coins: number, -- paid out, 0 when refused
	streak: number,
}

-- Applies a claim. Returns a new profile; the one passed in is not touched.
--
-- Refusing is a normal outcome, not an error: a second press on the same day, or a
-- request from a client that thinks it is a new day when the server does not.
function DailyRules.claim(profile: PlayerProfile, today: number, track: { number }): ClaimResult
	if not DailyRules.canClaim(profile, today) then
		return { claimed = false, profile = profile, coins = 0, streak = profile.streak }
	end

	local streak = DailyRules.nextStreak(profile, today)
	local coins = DailyRules.rewardFor(streak, track)
	local updated: PlayerProfile = {
		wins = profile.wins,
		roundsSurvived = profile.roundsSurvived,
		matchesPlayed = profile.matchesPlayed,
		coins = profile.coins + coins,
		lastClaimDay = today,
		streak = streak,
		musicPercent = profile.musicPercent,
		sfxPercent = profile.sfxPercent,
	}
	return { claimed = true, profile = updated, coins = coins, streak = streak }
end

-- What the panel shows: which track day is next, what it pays, whether the button is
-- live, and how long until the next one if it is not.
export type View = {
	canClaim: boolean,
	streak: number,
	trackDay: number, -- the day that claiming now would land on
	reward: number,
	secondsUntilNext: number,
}

function DailyRules.view(profile: PlayerProfile, unixTime: number, track: { number }): View
	local today = DailyRules.dayIndex(unixTime)
	local claimable = DailyRules.canClaim(profile, today)
	-- When a claim is available, show what claiming now would pay. When it is not, show
	-- the streak as it stands, so the panel is not promising a reward already taken.
	local streak = if claimable then DailyRules.nextStreak(profile, today) else profile.streak
	return {
		canClaim = claimable,
		streak = streak,
		trackDay = DailyRules.trackDay(streak, #track),
		reward = DailyRules.rewardFor(streak, track),
		secondsUntilNext = DailyRules.secondsUntilNextDay(unixTime),
	}
end

return DailyRules
