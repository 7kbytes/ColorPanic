--!strict
-- Player settings (A-07). Saves music and sound effect volume in the profile, so they
-- survive a rejoin.
--
-- Nothing here changes the game: volume is local to one player's ears. It still goes
-- through the server, because the profile is the server's and a client must not write to
-- it directly. What arrives is treated as a request, clamped by SettingsRules, and only
-- saved when it actually changed.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SettingsRules = require(ReplicatedStorage.Shared.SettingsRules)

local DataService = require(script.Parent.DataService)

local SettingsService = {}

local started = false
-- When each player may send another settings request. The panel steps the volume one
-- press at a time, and a held button must not turn into a stream of saves.
local nextRequestAllowed: { [Player]: number } = {}

local function onRequest(player: Player, payload: any)
	local now = os.clock()
	if (nextRequestAllowed[player] or 0) > now then
		return
	end
	nextRequestAllowed[player] = now + Config.Settings.requestCooldown

	local wanted = SettingsRules.readRequest(payload)
	if not wanted then
		return -- not a settings table; a client sending nonsense is ignored, not punished
	end

	local profile = DataService.getProfile(player)
	if not profile then
		return
	end
	if
		not SettingsRules.changed(
			profile.musicPercent,
			profile.sfxPercent,
			wanted.music,
			wanted.sfx
		)
	then
		return -- nothing to save
	end

	local updated = table.clone(profile)
	updated.musicPercent = wanted.music
	updated.sfxPercent = wanted.sfx
	DataService.setProfile(player, updated)
end

function SettingsService.start()
	assert(not started, "SettingsService.start() called twice")
	started = true

	Remotes.RequestSettings.connect(onRequest)
	Players.PlayerRemoving:Connect(function(player: Player)
		nextRequestAllowed[player] = nil
	end)
end

return SettingsService
