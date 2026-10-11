--!strict
-- Pure rules for player data sessions.
--
-- ProfileStore holds a profile on one server at a time, so two servers can never save over
-- each other. What is left for us to decide is what to do with each outcome of a session
-- request, and those decisions live here so they can be tested outside Studio with Lune.

local SessionRules = {}

-- How a player's data is being held for this session.
-- "live" means a real locked session: changes are saved.
-- "cache" means memory only: the game plays normally but nothing is written, so whatever
-- is already stored for that player is left untouched.
export type SessionMode = "live" | "cache"

export type StartDecision = {
	mode: SessionMode,
	-- True when the player must be removed from the server instead of playing on.
	kick: boolean,
	-- Why, for the kick message and the server log. Never shown raw to the player.
	reason: string,
}

-- The DataStore key for a player. One place so loading and saving cannot disagree.
function SessionRules.profileKey(userId: number): string
	return "player_" .. tostring(math.floor(userId))
end

-- Decides what to do with the result of a session request.
--
-- `storeAvailable` is false when DataStoreService is off or unreachable, which is the normal
-- case in Studio without API Services. `sessionStarted` is whether ProfileStore returned a
-- profile. `playerPresent` is whether the player is still in the server, since a session
-- request yields and they may have left while it ran.
function SessionRules.decideStart(
	storeAvailable: boolean,
	sessionStarted: boolean,
	playerPresent: boolean
): StartDecision
	if not playerPresent then
		-- They left while the request was running. Nothing to kick and nothing to hold.
		return { mode = "cache", kick = false, reason = "player left during load" }
	end

	if not storeAvailable then
		-- No store to lock against. Play on, but never write: a fresh profile saved over
		-- real stored data would wipe the player's progress.
		return { mode = "cache", kick = false, reason = "data store unavailable" }
	end

	if not sessionStarted then
		-- The store is there but the lock could not be taken, which means another server
		-- holds this profile. Playing on would mean an unsaved session, so the player is
		-- asked to rejoin instead.
		return { mode = "cache", kick = true, reason = "profile session is held elsewhere" }
	end

	return { mode = "live", kick = false, reason = "session started" }
end

-- Whether a session in this mode may write to the DataStore.
function SessionRules.canSave(mode: SessionMode): boolean
	return mode == "live"
end

-- Whether a session ending should remove the player. ProfileStore ends a session when we
-- ask it to, and also when another server takes the profile over. In the second case the
-- player is still in the game with data that can no longer be saved, so they are asked to
-- rejoin rather than play on unsaved.
function SessionRules.shouldKickOnSessionEnd(playerPresent: boolean, endedByUs: boolean): boolean
	return playerPresent and not endedByUs
end

return SessionRules
