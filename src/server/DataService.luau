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
-- The signature of each player's last successful save, so saveProfile can skip no-op writes.
local savedSignatures: { [Player]: string } = {}
-- Players whose stored profile could not be read. Their session is playable, but it must
-- never be saved over whatever is still in the DataStore.
local saveBlocked: { [Player]: boolean } = {}
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

-- Returns the named folder under `parent`, creating it if it is missing.
local function ensureFolder(parent: Instance, name: string): Instance
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

-- Returns the named IntValue under `parent`, replacing anything else of that name.
local function ensureIntValue(parent: Instance, name: string): IntValue
	local existing = parent:FindFirstChild(name)
	if existing then
		if existing:IsA("IntValue") then
			return existing
		end
		existing:Destroy()
	end
	local value = Instance.new("IntValue")
	value.Name = name
	value.Parent = parent
	return value
end

local function updateLeaderstats(player: Player, profile: PlayerProfile)
	local leaderstats = ensureFolder(player, "leaderstats")
	ensureIntValue(leaderstats, "Wins").Value = profile.wins
	ensureIntValue(leaderstats, "Coins").Value = profile.coins
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
		else
			-- The store is there but would not answer. Whatever this player has saved is
			-- still in it, and we do not know what it is, so a fresh profile must never be
			-- written over the top of it: that would wipe their progress on a brief outage.
			saveBlocked[player] = true
			warn(
				string.format(
					"[Data] Could not read %s, saving is off for this session so their"
						.. " stored progress is not overwritten",
					player.Name
				)
			)
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
	if not profile or saveBlocked[player] then
		return
	end
	-- Skip the write when nothing has changed since the last successful save. Roblox queues
	-- DataStore writes and drops them once the queue is full, so writing an unchanged profile
	-- every autosave costs budget that a real save may need later.
	local signature = DataRules.signature(profile)
	if savedSignatures[player] == signature then
		return
	end
	local key = "player_" .. tostring(player.UserId)
	if dataStoreAvailable and dataStore then
		local store = dataStore :: GlobalDataStore
		local success = retry(function()
			store:SetAsync(key, profile)
			return true -- retry expects the action to return a value
		end)
		if not success then
			return -- leave the signature alone so the next autosave tries again
		end
	end
	savedSignatures[player] = signature
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
		savedSignatures[player] = nil
		saveBlocked[player] = nil
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
