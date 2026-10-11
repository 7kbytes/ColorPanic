--!strict
-- Saves and loads player profiles, and manages leaderstats and rewards.
--
-- Player data is held through ProfileStore, which locks a profile to one server at a time
-- and saves it on its own schedule. That lock is what stops two servers writing over each
-- other when a player rejoins quickly or ends up in two places at once.
--
-- If there is no usable DataStore, which is the normal case in Studio without API Services,
-- the service runs every player in memory with saving switched off. The game stays fully
-- playable and nothing is written, so whatever is already stored is left untouched.
-- SessionRules holds the decisions and is tested outside Studio.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Config = require(ReplicatedStorage.Shared.Config)
local DataRules = require(ReplicatedStorage.Shared.DataRules)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local SessionRules = require(ReplicatedStorage.Shared.SessionRules)
local Types = require(ReplicatedStorage.Shared.Types)

type PlayerProfile = Types.PlayerProfile
type SessionMode = SessionRules.SessionMode

local DataService = {}

local started = false
local profiles: { [Player]: PlayerProfile } = {}
-- How each player's data is held. Only a "live" session is ever written.
local modes: { [Player]: SessionMode } = {}
-- The ProfileStore profile behind a live session, which owns the table that gets saved.
local sessions: { [Player]: any } = {}
-- Players whose session we ended ourselves, so OnSessionEnd can tell our own shutdown
-- apart from another server taking the profile over.
local endedByUs: { [Player]: boolean } = {}
-- True once the server is shutting down, so sessions ending then are not read as takeovers.
local serverClosing = false

local profileStore: any = nil
local storeAvailable = false

-- Loading ProfileStore ----------------------------------------------------------------

-- Requires ProfileStore from the Wally install. A missing package is a setup problem, not
-- a reason to take the server down, so it falls back to memory with saving off.
local function loadProfileStore(): any
	local packages = ServerScriptService:FindFirstChild("ServerPackages")
	local module = packages and packages:FindFirstChild("ProfileStore")
	if not module then
		warn("[Data] ProfileStore is not installed (run `wally install`); saving is off")
		return nil
	end
	local ok, result = pcall(require, module)
	if not ok then
		warn(
			string.format(
				"[Data] ProfileStore failed to load (%s); saving is off",
				tostring(result)
			)
		)
		return nil
	end
	return result
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

-- Checks once, at startup, whether this server can actually reach the DataStore.
--
-- This matters because a failed read and a profile held by another server both end a
-- session request with nothing, and they need opposite answers: a lock held elsewhere
-- should ask the player to rejoin, while an unreachable store should let everyone play on
-- without saving. One real request up front tells the two apart.
local function probeStore(): boolean
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore(Config.Data.dataStoreKey)
	end)
	if not ok or not store then
		warn(string.format("[Data] DataStore not available (%s); saving is off", tostring(store)))
		return false
	end
	local reachable = retry(function()
		return (store :: GlobalDataStore):GetAsync("session_probe")
	end)
	if not reachable then
		warn("[Data] DataStore did not answer; running in memory with saving off")
	end
	return reachable
end

-- Leaderstats -------------------------------------------------------------------------

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

-- Sessions ----------------------------------------------------------------------------

local function clearPlayer(player: Player)
	profiles[player] = nil
	modes[player] = nil
	sessions[player] = nil
	endedByUs[player] = nil
end

-- Ends a player's session so another server can take the profile. ProfileStore does a
-- final save as part of this.
local function endSession(player: Player)
	local session = sessions[player]
	if not session then
		clearPlayer(player)
		return
	end
	endedByUs[player] = true
	sessions[player] = nil
	pcall(function()
		session:EndSession()
	end)
	clearPlayer(player)
end

-- Writes the player's current profile into the table ProfileStore saves. Replacing that
-- table would not be noticed, so the fields are copied into it.
local function commit(player: Player, profile: PlayerProfile)
	profiles[player] = profile
	local session = sessions[player]
	if not session or not SessionRules.canSave(modes[player] or "cache") then
		return
	end
	-- IsActive can stop being true at any time, when another server takes the profile.
	-- Nothing is yielded between the check and the write.
	if session:IsActive() then
		DataRules.copyInto(session.Data, profile)
	end
end

-- Asks ProfileStore for a locked session. Returns the profile, or nil if the lock could
-- not be taken before the player left or the timeout ran out.
local function startSession(player: Player): any
	local deadline = os.clock() + Config.Data.Session.startTimeoutSeconds
	local ok, session = pcall(function()
		return profileStore:StartSessionAsync(SessionRules.profileKey(player.UserId), {
			-- ProfileStore calls this while it waits. Returning true gives up: either the
			-- player has gone, or we have waited long enough. Setting Cancel also turns
			-- off ProfileStore's own timeout, so this is the only one.
			Cancel = function()
				return player.Parent ~= Players or os.clock() > deadline
			end,
		})
	end)
	if not ok then
		warn(
			string.format(
				"[Data] Session request failed for %s: %s",
				player.Name,
				tostring(session)
			)
		)
		return nil
	end
	return session
end

local function loadProfile(player: Player)
	local session = if storeAvailable and profileStore then startSession(player) else nil
	local decision =
		SessionRules.decideStart(storeAvailable, session ~= nil, player.Parent == Players)

	if decision.kick then
		-- Only ever reached with no session, since a lock we hold is never a reason to kick.
		print(string.format("[Data] %s kicked: %s", player.Name, decision.reason))
		player:Kick(Config.Data.Session.heldElsewhereMessage)
		clearPlayer(player)
		return
	end

	if player.Parent ~= Players then
		-- They left while the request ran. Hand the lock straight back.
		if session then
			pcall(function()
				session:EndSession()
			end)
		end
		clearPlayer(player)
		return
	end

	modes[player] = decision.mode

	local profile: PlayerProfile
	if session then
		session:AddUserId(player.UserId) -- so the profile can be found for GDPR requests
		session:Reconcile()
		-- Stored data is still sanitized: the lock says who may write, not that what was
		-- written is valid.
		profile = DataRules.sanitize(session.Data)
		DataRules.copyInto(session.Data, profile)
		sessions[player] = session

		session.OnSessionEnd:Connect(function()
			local present = player.Parent == Players
			-- A shutdown ends every session, and that is our own doing, not a takeover.
			local ours = endedByUs[player] == true or serverClosing
			if SessionRules.shouldKickOnSessionEnd(present, ours) then
				warn(string.format("[Data] %s: profile taken over by another server", player.Name))
				player:Kick(Config.Data.Session.takenOverMessage)
			end
			sessions[player] = nil
		end)
	else
		profile = DataRules.sanitize(nil)
	end

	profiles[player] = profile
	updateLeaderstats(player, profile)
	Remotes.PlayerDataUpdated.fireTo(player, { profile = profile })
	print(
		string.format(
			"[Data] Loaded %s: %d wins, %d coins (%s)",
			player.Name,
			profile.wins,
			profile.coins,
			decision.mode
		)
	)
end

-- Public API --------------------------------------------------------------------------

function DataService.getProfile(player: Player): PlayerProfile?
	return profiles[player]
end

function DataService.awardRoundSurvivors(survivors: { Player })
	for _, player in survivors do
		local profile = profiles[player]
		if profile then
			local updated = DataRules.recordRoundSurvived(profile, Config.Rewards.coinsPerRound)
			commit(player, updated)
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
			commit(player, updated)
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
			commit(player, updated)
			Remotes.PlayerDataUpdated.fireTo(player, { profile = updated })
		end
	end
end

function DataService.start()
	assert(not started, "DataService.start() called twice")
	started = true

	local profileStoreModule = loadProfileStore()
	if profileStoreModule and probeStore() then
		local ok, store = pcall(function()
			return profileStoreModule.New(Config.Data.dataStoreKey, DataRules.defaultProfile())
		end)
		if ok and store then
			profileStore = store
			storeAvailable = true
		else
			warn(
				string.format("[Data] ProfileStore.New failed (%s); saving is off", tostring(store))
			)
		end
	end

	-- Sessions yield, so each player is loaded on its own thread.
	for _, player in Players:GetPlayers() do
		task.spawn(loadProfile, player)
	end
	Players.PlayerAdded:Connect(function(player: Player)
		task.spawn(loadProfile, player)
	end)
	Players.PlayerRemoving:Connect(endSession)

	-- ProfileStore saves active sessions on shutdown and autosaves on its own schedule, so
	-- there is no autosave loop here. This only records that a shutdown is underway, so the
	-- sessions ProfileStore then ends are not mistaken for another server taking over.
	game:BindToClose(function()
		serverClosing = true
	end)
end

return DataService
