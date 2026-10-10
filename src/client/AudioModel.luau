--!strict
-- Which sounds play when (D-08), kept pure so it can be tested outside Studio. Every cue follows
-- something the server sent; the client only picks the sound.

export type Cue = "roundStart" | "tileDrop" | "survived" | "winFanfare"

export type Music = "lobbyMusic" | "matchMusic"

-- What the client knows about itself at a state change.
export type Context = {
	playing: boolean, -- was a Survivor in this round
	eliminated: boolean, -- the server eliminated this player this match
	fell: boolean, -- this player's character fell in this round's Elimination
	finalRound: boolean, -- this round is the match's last (the round cap)
}

export type Tick = { second: number, final: boolean }

-- States outside a match, which get the lobby music.
local OUT_OF_MATCH: { [string]: boolean } = {
	Lobby = true,
	Intermission = true,
	Reset = true,
}

local AudioModel = {}

-- The sounds to play when the match enters `state`.
function AudioModel.onState(state: string, context: Context): { Cue }
	if state == "RoundIntro" then
		return { "roundStart" }
	elseif state == "Elimination" then
		return { "tileDrop" }
	elseif state == "RoundEnd" then
		-- Only for a player still standing, and not on the last round, which goes straight to
		-- Victory and its fanfare.
		local survived = context.playing
			and not context.eliminated
			and not context.fell
			and not context.finalRound
		return if survived then { "survived" } else {}
	elseif state == "Victory" then
		return { "winFanfare" }
	end
	return {}
end

-- The countdown tick due at `remaining` seconds left, or nil. Ticks on each of the last
-- `warningSeconds` whole seconds of Run, once per second (`lastTicked` is the second last
-- ticked); the last one is marked final so it can be pitched up.
function AudioModel.tick(
	state: string?,
	remaining: number,
	warningSeconds: number,
	lastTicked: number?
): Tick?
	if state ~= "Run" or remaining <= 0 then
		return nil
	end
	local second = math.ceil(remaining)
	if second > warningSeconds or second == lastTicked then
		return nil
	end
	return { second = second, final = second == 1 }
end

-- The music for `state` and the local player's `role`: the lobby track in the menu and
-- between matches, the match track while a match runs.
function AudioModel.music(state: string?, role: string?): Music
	if role == nil or role == "Menu" or state == nil or OUT_OF_MATCH[state] then
		return "lobbyMusic"
	end
	return "matchMusic"
end

return AudioModel
