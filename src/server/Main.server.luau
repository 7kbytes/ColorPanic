--!strict
-- Server entry point. Creates the remotes, then starts the services.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

Remotes.initServer()

local MatchService = require(script.Parent.MatchService)
MatchService.start()

print("[Server] Color Panic server started")
