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

local MatchService = require(script.Parent.MatchService)
MatchService.start()

print("[Server] Color Panic server started")
