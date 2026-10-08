--!strict
-- Server entry point. Services are wired up here in later tasks.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

Remotes.initServer()

print("[Server] Color Panic server started")
