--!strict
-- Client entry point. Starts the client controllers.

local HUDController = require(script.Parent.HUDController)
local MenuController = require(script.Parent.MenuController)
local SpectateController = require(script.Parent.SpectateController)

HUDController.start()
MenuController.start()
SpectateController.start()

print("[Client] Color Panic client started")
