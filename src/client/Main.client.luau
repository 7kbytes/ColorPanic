--!strict
-- Client entry point. Starts the client controllers.

local AudioController = require(script.Parent.AudioController)
local HUDController = require(script.Parent.HUDController)
local LookController = require(script.Parent.LookController)
local MenuController = require(script.Parent.MenuController)
local Puffs = require(script.Parent.Puffs)
local SpectateController = require(script.Parent.SpectateController)

HUDController.start()
MenuController.start()
SpectateController.start()
AudioController.start()
LookController.start()
Puffs.start()

print("[Client] Color Panic client started")
