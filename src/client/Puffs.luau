--!strict
-- Dust puffs (A-10): a burst where a tile drops away, and a smaller one under a player who
-- lands on one. Visual only, and entirely local: the server destroys tiles and never says
-- anything about dust, so nothing here can disagree with the match.
--
-- Tiles are removed by being destroyed, with no fall, so the puff is what sells the drop.
-- The catch is that tiles are also destroyed wholesale when the arena is rebuilt between
-- rounds, and puffing then would fog the whole arena. Removals are therefore collected over
-- a frame and only puffed when tiles are left behind: ArenaService.removeNonTarget always
-- leaves the target colour standing, while a clear leaves the folder empty.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local ARENA = Config.Arena
local ART = Config.Art
local PUFF = ART.Puff

local Puffs = {}

local started = false

local function tilesFolder(): Instance?
	local arena = workspace:FindFirstChild(ARENA.folderName)
	return if arena then arena:FindFirstChild(ARENA.tilesFolderName) else nil
end

-- One burst of `count` particles at `position`, cleaned up by Debris so a puff can never
-- outlive its round or leak if the arena goes while it is still in the air.
local function burst(position: Vector3, count: number)
	local id = Config.Assets.Images.dustPuff
	if not ART.enabled or id == 0 or count <= 0 then
		return
	end
	local anchor = Instance.new("Part")
	anchor.Name = "Puff"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = position
	anchor.Parent = workspace

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxassetid://" .. tostring(id)
	emitter.Rate = 0 -- emitted as one burst below, not a trickle
	emitter.Lifetime = NumberRange.new(PUFF.lifetime[1], PUFF.lifetime[2])
	emitter.Speed = NumberRange.new(PUFF.speed[1], PUFF.speed[2])
	emitter.Size = NumberSequence.new(PUFF.size)
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, PUFF.transparency),
		NumberSequenceKeypoint.new(1, 1), -- fade out rather than blink away
	})
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.Parent = anchor
	emitter:Emit(count)

	-- Long enough for the last particle to finish its life, plus the linger in Config.
	Debris:AddItem(anchor, PUFF.lifetime[2] + PUFF.seconds)
end

-- Removals seen this frame, flushed together so a round's worth of drops is one decision.
local pending: { Vector3 } = {}
local flushQueued = false

local function flush()
	flushQueued = false
	local positions = pending
	pending = {}
	local folder = tilesFolder()
	-- Nothing left standing means the arena was cleared, not that tiles dropped.
	if not folder or #folder:GetChildren() == 0 then
		return
	end
	for _, position in positions do
		burst(position, PUFF.dropCount)
	end
end

local function watchTiles(folder: Instance)
	folder.ChildRemoved:Connect(function(child)
		if not child:IsA("BasePart") then
			return
		end
		-- The instance is destroyed but its properties still read, so this is the tile's
		-- last position.
		table.insert(pending, child.Position)
		if not flushQueued then
			flushQueued = true
			task.defer(flush)
		end
	end)
end

-- The arena folder is built by the server and rebuilt between rounds, so the watch follows
-- whichever Tiles folder is current rather than binding once at startup.
local function watchArena()
	local function bind(folder: Instance)
		if folder.Name == ARENA.tilesFolderName then
			watchTiles(folder)
		end
	end
	local function bindArena(arena: Instance)
		if arena.Name ~= ARENA.folderName then
			return
		end
		local existing = arena:FindFirstChild(ARENA.tilesFolderName)
		if existing then
			bind(existing)
		end
		arena.ChildAdded:Connect(bind)
	end
	local arena = workspace:FindFirstChild(ARENA.folderName)
	if arena then
		bindArena(arena)
	end
	workspace.ChildAdded:Connect(bindArena)
end

-- A puff under the player's feet when they land, so a drop onto a tile has some weight.
local function watchLanding()
	local function bindCharacter(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if not humanoid or not humanoid:IsA("Humanoid") then
			return
		end
		humanoid.StateChanged:Connect(function(_, new)
			if new ~= Enum.HumanoidStateType.Landed then
				return
			end
			local root = character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				-- Roughly at the feet rather than the hips.
				burst(root.Position - Vector3.new(0, root.Size.Y, 0), PUFF.landCount)
			end
		end)
	end
	local player = Players.LocalPlayer
	if player.Character then
		bindCharacter(player.Character)
	end
	player.CharacterAdded:Connect(bindCharacter)
end

function Puffs.start()
	if started then
		return
	end
	started = true
	if not ART.enabled or Config.Assets.Images.dustPuff == 0 then
		return
	end
	watchArena()
	watchLanding()
end

return Puffs
