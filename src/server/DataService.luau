--!strict
-- Saves and loads player profiles, and manages leaderstats and rewards.
-- Runs on the server. If DataStoreService is disabled or fails, it falls back
-- to an in-memory session cache so play and testing never crash.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataRules = require(ReplicatedStorage.Shared.DataRules)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Types = require(ReplicatedStorage.Shared.Types)

type PlayerProfile = Types.PlayerProfile

local DataService = {}

local started = false
local profiles: { [Player]: PlayerProfile } = {}
local dataStore: GlobalDataStore? = nil
local dataStoreAvailable = false

local function initStore()
	local ok, storeOrErr = pcall(function()
		return DataStoreService:GetDataStore(Config.Data.dataStoreKey)
	end)
	if ok and storeOrErr then
		dataStore = storeOrErr
		dataStoreAvailable = true
	else
		warn(
			string.format(
				"[Data] DataStore not available (%s); running with session cache",
				tostring(storeOrErr)
			)
		)
	end
end

local function retry<T>(action: () -> T): (boolean, T?)
	local result: T? = nil
	for attempt = 1, Config.Data.maxRetries do
		local success, err = pcall(function()
			result = action()
		end)
		if success then
			return true, result
		end
		if attempt < Config.Data.maxRetries then
			task.wait(Config.Data.retryDelaySeconds)
		else
			warn(
				string.format(
					"[Data] DataStore error after %d attempts: %s",
					Config.Data.maxRetries,
					tostring(err)
				)
			)
		end
	end
	return false, nil
end

local function updateLeaderstats(player: Player, profile: PlayerProfile)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		local folder = Instance.new("Folder")
		folder.Name = "leaderstats"
		folder.Parent = player
		leaderstats = folder
	end

	local winsValue = leaderstats:FindFirstChild("Wins")
	if not (winsValue and winsValue:IsA("IntValue")) then
		local val = Instance.new("IntValue")
		val.Name = "Wins"
		val.Parent = leaderstats
		winsValue = val
	end
	(winsValue :: IntValue).Value = profile.wins

	local coinsValue = leaderstats:FindFirstChild("Coins")
	if not (coinsValue and coinsValue:IsA("IntValue")) then
		local val = Instance.new("IntValue")
		val.Name = "Coins"
		val.Parent = leaderstats
		coinsValue = val
	end
	(coinsValue :: IntValue).Value = profile.coins
end

local function loadProfile(player: Player): PlayerProfile
	local key = "player_" .. tostring(player.UserId)
	local rawData = nil
	if dataStoreAvailable and dataStore then
		local success, result = retry(function()
			return (dataStore :: GlobalDataStore):GetAsync(key)
		end)
		if success then
			rawData = result
		end
	end

	local profile = DataRules.sanitize(rawData)
	profiles[player] = profile
	updateLeaderstats(player, profile)
	Remotes.PlayerDataUpdated.fireTo(player, { profile = profile })
	print(
		string.format(
			"[Data] Loaded %s: %d wins, %d coins",
			player.Name,
			profile.wins,
			profile.coins
		)
	)
	return profile
end

local function saveProfile(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	local key = "player_" .. tostring(player.UserId)
	if dataStoreAvailable and dataStore then
		retry(function()
			(dataStore :: GlobalDataStore):SetAsync(key, profile)
		end)
	end
end

function DataService.getProfile(player: Player): PlayerProfile?
	return profiles[player]
end

function DataService.awardRoundSurvivors(survivors: { Player })
	for _, player in survivors do
		local profile = profiles[player]
		if profile then
			local updated = DataRules.recordRoundSurvived(profile, Config.Rewards.coinsPerRound)
			profiles[player] = updated
			updateLeaderstats(player, updated)
			Remotes.PlayerDataUpdated.fireTo(player, { profile = updated })
		end
	end
end

function DataService.awardMatchWinners(winners: { Player })
	for _, player in winners do
		local profile = profiles[player]
		if profile then
			local updated = DataRules.recordMatchVictory(profile, Config.Rewards.coinsPerWin)
			profiles[player] = updated
			updateLeaderstats(player, updated)
			Remotes.PlayerDataUpdated.fireTo(player, { profile = updated })
		end
	end
end

function DataService.recordMatchPlayed(participants: { Player })
	for _, player in participants do
		local profile = profiles[player]
		if profile then
			local updated = DataRules.recordMatchPlayed(profile)
			profiles[player] = updated
			Remotes.PlayerDataUpdated.fireTo(player, { profile = updated })
		end
	end
end

function DataService.start()
	assert(not started, "DataService.start() called twice")
	started = true

	initStore()

	for _, player in Players:GetPlayers() do
		loadProfile(player)
	end

	Players.PlayerAdded:Connect(loadProfile)
	Players.PlayerRemoving:Connect(function(player: Player)
		saveProfile(player)
		profiles[player] = nil
	end)

	game:BindToClose(function()
		for player in profiles do
			saveProfile(player)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(Config.Data.autoSaveSeconds)
			for player in profiles do
				saveProfile(player)
			end
		end
	end)
end

return DataService
