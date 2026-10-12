--!strict
-- Daily rewards (A-08). One claim per UTC day, with a streak.
--
-- The server owns the clock. A claim request carries no payload and no time: the client
-- asks, and the server decides from os.time() whether a day has actually passed. A client
-- that changed its own clock, or sent the request twenty times, gets exactly one reward.
--
-- The rules are in shared/DailyRules, which is pure and tested. This service is the part
-- that touches players, profiles and remotes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DailyRules = require(ReplicatedStorage.Shared.DailyRules)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)

local DataService = require(script.Parent.DataService)

type PlayerProfile = Types.PlayerProfile

local DAILY = Config.Daily

local DailyRewardsService = {}

local started = false
-- When each player may send another claim request. Stops a held button turning into a
-- stream of requests, which the rules would refuse anyway but which still costs work.
local nextRequestAllowed: { [Player]: number } = {}

local function sendState(player: Player)
	local profile = DataService.getProfile(player)
	if not profile then
		return -- their profile has not loaded yet; the load itself sends the state
	end
	local view = DailyRules.view(profile, os.time(), DAILY.track)
	Remotes.DailyUpdated.fireTo(player, {
		canClaim = view.canClaim,
		streak = view.streak,
		trackDay = view.trackDay,
		reward = view.reward,
		secondsUntilNext = view.secondsUntilNext,
		track = DAILY.track,
	})
end

DailyRewardsService.sendState = sendState

local function onClaimRequest(player: Player)
	local now = os.clock()
	if (nextRequestAllowed[player] or 0) > now then
		return
	end
	nextRequestAllowed[player] = now + DAILY.claimCooldown

	local profile = DataService.getProfile(player)
	if not profile then
		return
	end

	local result = DailyRules.claim(profile, DailyRules.dayIndex(os.time()), DAILY.track)
	if not result.claimed then
		-- Already claimed today. Send the state back anyway so a client showing a live
		-- button corrects itself.
		sendState(player)
		return
	end

	DataService.setProfile(player, result.profile)
	print(
		string.format(
			"[Daily] %s claimed day %d of the streak for %d coins",
			player.Name,
			result.streak,
			result.coins
		)
	)
	sendState(player)
end

function DailyRewardsService.start()
	assert(not started, "DailyRewardsService.start() called twice")
	started = true

	Remotes.RequestDailyClaim.connect(onClaimRequest)

	Players.PlayerRemoving:Connect(function(player: Player)
		nextRequestAllowed[player] = nil
	end)

	-- A player gets their state once their profile is in. The profile load yields, so this
	-- waits for it rather than racing it.
	--
	-- Both paths wait. The first version sent to already-present players immediately and
	-- only waited for later joiners, which meant anyone in the server when it started got
	-- nothing at all: their profile had not loaded yet, sendState returned early, and
	-- nothing ever sent it again. In Studio that is every test, and on a real server it is
	-- the first players through the door. The panel just sat on its defaults.
	local function sendWhenLoaded(player: Player)
		task.spawn(function()
			for _ = 1, Config.Daily.profileWaitTries do
				if DataService.getProfile(player) then
					break
				end
				task.wait(Config.Daily.profileWaitSeconds)
			end
			sendState(player)
		end)
	end

	for _, player in Players:GetPlayers() do
		sendWhenLoaded(player)
	end
	Players.PlayerAdded:Connect(sendWhenLoaded)
end

return DailyRewardsService
