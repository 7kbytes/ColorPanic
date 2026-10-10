--!strict
-- Client entry point. Starts the client controllers.

local AudioController = require(script.Parent.AudioController)
local HUDController = require(script.Parent.HUDController)
local MenuController = require(script.Parent.MenuController)
local SpectateController = require(script.Parent.SpectateController)

HUDController.start()
MenuController.start()
SpectateController.start()
AudioController.start()

print("[Client] Color Panic client started")
