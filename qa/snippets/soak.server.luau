-- QA only. Server command bar: records a soak run across several matches (H-05).
--
-- Paste this once, at the start of the soak, then let matches play. It samples at every
-- Reset, which is the moment the arena is supposed to be empty again. Read the report back
-- at any time with:  _G.soakdump()
--
-- What it is looking for is drift: the part count and the memory should come back to about
-- the same numbers after every match. A figure that climbs match after match is a leak.

local LogService = game:GetService("LogService")
local Players = game:GetService("Players")
local Stats = game:GetService("Stats")

-- BaseParts in the workspace, not counting player characters, which come and go with
-- players. The same rule MatchService uses for its reset audit, so the numbers line up.
local function countWorkspaceParts(): number
	local characters = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(characters, player.Character)
		end
	end
	local count = 0
	for _, instance in workspace:GetDescendants() do
		if instance:IsA("BasePart") then
			local inCharacter = false
			for _, character in characters do
				if instance:IsDescendantOf(character) then
					inCharacter = true
					break
				end
			end
			if not inCharacter then
				count += 1
			end
		end
	end
	return count
end

if _G.soakConnection then
	_G.soakConnection:Disconnect() -- pasted twice: start again rather than record double
end

local samples = {}
local problems = {}
_G.soaksamples = samples
_G.soakproblems = problems

local baseline = {
	parts = countWorkspaceParts(),
	memory = Stats:GetTotalMemoryUsageMb(),
	players = #Players:GetPlayers(),
}
_G.soakbaseline = baseline

local function record(message: string)
	-- MatchService prints "[Reset] Clean" or "[Reset] Problems: ..." once per match.
	if string.find(message, "%[Reset%]") then
		table.insert(samples, {
			match = #samples + 1,
			clean = string.find(message, "Clean") ~= nil,
			parts = countWorkspaceParts(),
			memory = Stats:GetTotalMemoryUsageMb(),
			players = #Players:GetPlayers(),
			clock = math.floor(os.clock()),
		})
		if not string.find(message, "Clean") then
			table.insert(problems, string.format("match %d: %s", #samples, message))
		end
	elseif string.find(message, "%[Data%]") and string.find(message, "cache") then
		-- Worth knowing during a soak: saving was off for this run.
		table.insert(problems, "saving was off: " .. message)
	end
end

_G.soakConnection = LogService.MessageOut:Connect(function(message, messageType)
	if messageType == Enum.MessageType.MessageError then
		table.insert(problems, "ERROR " .. message)
	elseif messageType == Enum.MessageType.MessageWarning then
		table.insert(problems, "WARN " .. message)
	else
		record(message)
	end
end)

-- Returns the report as text, so it can be pasted straight into the QA record.
_G.soakdump = function(): string
	local lines = {
		string.format(
			"baseline: %d parts, %.1f MB, %d players",
			baseline.parts,
			baseline.memory,
			baseline.players
		),
		"match | clean | parts (drift) | memory MB (drift) | players",
	}
	for _, sample in samples do
		table.insert(
			lines,
			string.format(
				"%5d | %5s | %5d (%+d) | %8.1f (%+.1f) | %d",
				sample.match,
				tostring(sample.clean),
				sample.parts,
				sample.parts - baseline.parts,
				sample.memory,
				sample.memory - baseline.memory,
				sample.players
			)
		)
	end
	if #samples == 0 then
		table.insert(lines, "(no resets recorded yet; let a match finish)")
	end
	table.insert(lines, string.format("problems: %d", #problems))
	for _, problem in problems do
		table.insert(lines, "  " .. problem)
	end
	return table.concat(lines, "\n")
end

return string.format(
	"Soak recording started. Baseline %d parts, %.1f MB. Read it back with _G.soakdump()",
	baseline.parts,
	baseline.memory
)
