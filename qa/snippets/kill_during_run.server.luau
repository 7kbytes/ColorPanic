-- QA only. Server command bar: kills NAME's character a moment into the next Run, while it is
-- standing on the arena. Gives up after TIMEOUT seconds.
local NAME = "Player1"
local DELAY = 2 -- seconds after reaching the arena
local TIMEOUT = 180

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local half = Config.Arena.gridSize * Config.Arena.tileSize / 2
local arenaY = Config.Arena.origin[2]

task.spawn(function()
	local started = os.clock()
	while os.clock() - started < TIMEOUT do
		local player = Players:FindFirstChild(NAME) :: Player?
		local character = player and player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and humanoid then
			local position = root.Position
			if
				math.abs(position.X) <= half
				and math.abs(position.Z) <= half
				and math.abs(position.Y - arenaY) < 10
			then
				task.wait(DELAY)
				humanoid.Health = 0
				print(
					string.format(
						"[QA] killed %s at %.1f",
						NAME,
						workspace:GetServerTimeNow() % 1000
					)
				)
				return
			end
		end
		task.wait(0.2)
	end
	print("[QA] kill timed out for " .. NAME)
end)
return "armed kill for " .. NAME
