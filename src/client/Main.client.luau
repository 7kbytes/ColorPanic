--!strict
-- Client entry point. Starts the client controllers.

local HUDController = require(script.Parent.HUDController)
local MenuController = require(script.Parent.MenuController)

HUDController.start()
MenuController.start()

print("[Client] Color Panic client started")
