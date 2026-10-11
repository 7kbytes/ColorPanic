--!strict
-- Server entry point. Creates the remotes, then starts the services.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

Remotes.initServer()

local DataService = require(script.Parent.DataService)
DataService.start()

-- Before MatchService, so the props count in the reset audit's part baseline.
local LookService = require(script.Parent.LookService)
LookService.start()

-- Also before MatchService: the prop colliders are parts, and the reset audit compares the
-- workspace part count against a baseline taken when MatchService starts.
local PropCollision = require(script.Parent.PropCollision)
PropCollision.start()

-- Also before MatchService: the board is a part, and the reset audit counts parts.
local LeaderboardService = require(script.Parent.LeaderboardService)
LeaderboardService.start()

local DailyRewardsService = require(script.Parent.DailyRewardsService)
DailyRewardsService.start()

local MatchService = require(script.Parent.MatchService)
MatchService.start()

print("[Server] Color Panic server started")
