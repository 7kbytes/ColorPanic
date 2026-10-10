-- QA only. Client command bar: sends the same Play request as the menu's Play button (D-16).
-- Players start in the menu and do not count toward a match until they press Play.
-- Set LEAVE = true to send Leave instead (accepted only in the lobby before a match).
local LEAVE = false

local Remotes = require(game:GetService("ReplicatedStorage").Shared.Remotes)
local player = game:GetService("Players").LocalPlayer
if LEAVE then
	Remotes.RequestLeave.fire()
else
	Remotes.RequestPlay.fire()
end
task.wait(1)
return string.format(
	"%s sent %s, role now %s",
	player.Name,
	if LEAVE then "Leave" else "Play",
	tostring(player:GetAttribute("MatchRole"))
)
