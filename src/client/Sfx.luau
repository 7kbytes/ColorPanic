--!strict
-- Plays the game's sounds on this client (D-08). Each sound is created once, under SoundService,
-- from its asset ID in Config.Assets.Sounds; an ID of 0 means the sound is skipped.

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)

export type Name =
	"click"
	| "tick"
	| "roundStart"
	| "reveal"
	| "tileDrop"
	| "fall"
	| "eliminated"
	| "survived"
	| "winFanfare"
	| "lobbyMusic"
	| "matchMusic"

local Sfx = {}

local sounds: { [Name]: Sound } = {}

-- The Sound for `name`, or nil when it has no asset ID.
function Sfx.get(name: Name): Sound?
	local existing = sounds[name]
	if existing then
		return existing
	end
	local id = (Config.Assets.Sounds :: { [string]: number })[name]
	if not id or id == 0 then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = "rbxassetid://" .. tostring(id)
	sound.Volume = Config.Audio.sfxVolume
	sound.Parent = SoundService
	sounds[name] = sound
	-- Audio is private to its owner, so a missing permission shows up here as a failed load.
	task.spawn(function()
		ContentProvider:PreloadAsync({ sound }, function(_, status)
			if status == Enum.AssetFetchStatus.Success then
				print(string.format("[Audio] %s loaded", name))
			else
				warn(string.format("[Audio] %s (%d) did not load (%s)", name, id, tostring(status)))
			end
		end)
	end)
	return sound
end

-- Creates and starts loading every sound, so the first time each one plays it is ready. Call
-- once when the client starts; otherwise a sound only loads the first time it is played.
function Sfx.preloadAll()
	for name in Config.Assets.Sounds :: { [string]: number } do
		Sfx.get(name :: Name)
	end
end

-- Plays `name` from the start, at `pitch` times normal speed (default 1).
function Sfx.play(name: Name, pitch: number?)
	local sound = Sfx.get(name)
	if not sound then
		return
	end
	sound.PlaybackSpeed = pitch or 1
	sound.TimePosition = 0
	sound:Play()
	if Config.Audio.logCues then
		print(
			string.format(
				"[Audio] play %s x%.2f at %.2f",
				name,
				pitch or 1,
				workspace:GetServerTimeNow() % 1000
			)
		)
	end
end

return Sfx
