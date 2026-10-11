--!strict
-- What the loading screen shows, kept pure so it can be tested outside Studio.
-- The screen itself is src/replicatedfirst/LoadingScreen.client.luau.

local LoadingModel = {}

-- Shown under the progress bar, one at a time. Short enough to read while loading.
LoadingModel.TIPS = {
	"Every color always has the same shape.",
	"From round 3 the target hides. Memorize it.",
	"From round 4 the tiles start shrinking.",
	"Standing in the gap between tiles counts as a miss.",
	"Last one standing wins the match.",
}

-- The fraction of assets loaded, always between 0 and 1.
-- Guards the divide: a preload list can legitimately be empty.
function LoadingModel.progress(done: number, total: number): number
	if total <= 0 then
		return 1
	end
	return math.clamp(done / total, 0, 1)
end

-- The percentage caption, for example "42%".
function LoadingModel.percentText(done: number, total: number): string
	return string.format("%d%%", math.floor(LoadingModel.progress(done, total) * 100 + 0.5))
end

-- The tip to show at `elapsed` seconds, cycling every `seconds`.
function LoadingModel.tipAt(elapsed: number, seconds: number): string
	local tips = LoadingModel.TIPS
	if seconds <= 0 then
		return tips[1]
	end
	local index = math.floor(math.max(elapsed, 0) / seconds) % #tips
	return tips[index + 1]
end

-- Whether the screen may close.
--
-- Three things have to be true: the game is loaded, preloading has finished or given up,
-- and the screen has been up for at least `minSeconds`. The minimum stops the screen
-- flashing on and off on a fast rejoin, which reads as a glitch.
function LoadingModel.canClose(
	gameLoaded: boolean,
	preloadFinished: boolean,
	elapsed: number,
	minSeconds: number
): boolean
	return gameLoaded and preloadFinished and elapsed >= minSeconds
end

-- Whether to stop waiting on preloading and let the player in anyway.
--
-- A single asset that never resolves must not trap someone on the loading screen for ever,
-- so preloading is given a deadline. Missing art is a visible but survivable problem; a
-- player stuck staring at a progress bar is not.
function LoadingModel.preloadTimedOut(elapsed: number, timeoutSeconds: number): boolean
	return timeoutSeconds > 0 and elapsed >= timeoutSeconds
end

return LoadingModel
