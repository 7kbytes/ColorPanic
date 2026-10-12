--!strict
-- Sound effects and music (D-08). Listens to the same server remotes as the HUD and plays the
-- cues AudioModel picks. Cosmetic and local only: nothing here reaches the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local AudioModel = require(script.Parent.AudioModel)
local HudModel = require(script.Parent.HudModel)
local Sfx = require(script.Parent.Sfx)

local MATCH_ROLE_ATTRIBUTE = "MatchRole"

local AudioController = {}

local started = false
local player = Players.LocalPlayer

local function role(): string?
	local value = player:GetAttribute(MATCH_ROLE_ATTRIBUTE)
	return if type(value) == "string" then value else nil
end

-- True once the local character has dropped below the arena tiles by the elimination margin.
local function hasFallen(): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return false
	end
	local tileTop = Config.Arena.origin[2] + Config.Arena.tileHeight / 2
	return root.Position.Y < tileTop - Config.Elimination.fallMargin
end

function AudioController.start()
	assert(not started, "AudioController.start() called twice")
	started = true
	Sfx.preloadAll()

	local model = HudModel.new()
	local playing = false -- a Survivor in the current round
	local eliminated = false -- eliminated this match
	local fell = false -- fell in this round's Elimination
	local lastTicked: number? = nil
	local targetHidden: boolean? = nil -- the target card's hidden state last frame

	-- Music: both tracks loop; switching fades one out and the other in.
	local currentMusic: AudioModel.Music? = nil
	local function fadeTo(sound: Sound, volume: number)
		local info = TweenInfo.new(Config.Audio.musicFadeSeconds)
		TweenService:Create(sound, info, { Volume = volume }):Play()
	end
	local function playMusic(name: AudioModel.Music)
		if name == currentMusic then
			return
		end
		local previous = if currentMusic then Sfx.get(currentMusic) else nil
		currentMusic = name
		if previous then
			fadeTo(previous, 0)
		end
		local sound = Sfx.get(name)
		if sound then
			sound.Looped = true
			if not sound.IsPlaying then
				sound.Volume = 0
				sound:Play()
			end
			fadeTo(sound, Sfx.volumeFor(name))
		end
	end

	Remotes.StateChanged.connect(function(payload)
		HudModel.applyState(model, payload)
		local state = payload.state
		lastTicked = nil
		if state == "RoundIntro" then
			playing = role() == "Survivor"
			fell = false
		elseif state == "Lobby" or state == "Intermission" then
			eliminated = false
			playing = false
		end
		local round = model.round
		local cues = AudioModel.onState(state, {
			playing = playing,
			eliminated = eliminated,
			fell = fell,
			finalRound = round ~= nil and round >= Config.Match.maxRounds,
		})
		for _, cue in cues do
			Sfx.play(cue :: Sfx.Name)
		end
	end)
	Remotes.RoundInfo.connect(function(payload)
		HudModel.applyRoundInfo(model, payload)
	end)
	Remotes.TargetAnnounced.connect(function(payload)
		HudModel.applyTarget(model, payload, workspace:GetServerTimeNow())
	end)
	Remotes.PlayerEliminated.connect(function(payload)
		if payload.userId == player.UserId then
			eliminated = true
			Sfx.play("eliminated")
		end
	end)

	RunService.Heartbeat:Connect(function()
		local now = workspace:GetServerTimeNow()
		local state = model.state

		-- Countdown ticks in the last seconds of Run.
		local endsAt = model.endsAt
		if endsAt then
			local tick = AudioModel.tick(state, endsAt - now, Config.Hud.warningSeconds, lastTicked)
			if tick then
				lastTicked = tick.second
				Sfx.play("tick", if tick.final then Config.Audio.tickFinalPitch else 1)
			end
		end

		-- Reveal-then-hide: a chime when the target shows, the same chime lower when it hides.
		local hidden = HudModel.targetView(model, now).hidden
		if state == "Run" and targetHidden ~= nil and hidden ~= targetHidden then
			Sfx.play("reveal", if hidden then Config.Audio.hidePitch else 1)
		end
		targetHidden = hidden

		-- The local player's own fall, once per round.
		if state == "Elimination" and playing and not fell and hasFallen() then
			fell = true
			Sfx.play("fall")
		end

		playMusic(AudioModel.music(state, role()))
	end)
end

return AudioController
