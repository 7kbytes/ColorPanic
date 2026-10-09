--# selene: allow(global_usage)
-- QA only. Client command bar: logs every HUD change with server time into _G.hudlog.
local player = game:GetService("Players").LocalPlayer
_G.hudlog = {}
_G.hudRecorderRunning = true
task.spawn(function()
	local last = ""
	while _G.hudRecorderRunning do
		local hud = player.PlayerGui:FindFirstChild("HUD")
		if hud then
			local panel = hud.Panel
			local line = table.concat({
				panel.state.Text,
				panel.round.Text,
				panel.target.Text,
				panel.playersLeft.Text,
			}, " | ")
			if line ~= last then
				last = line
				table.insert(
					_G.hudlog,
					string.format("%.2f %s", workspace:GetServerTimeNow() % 1000, line)
				)
			end
		end
		task.wait()
	end
end)
return "recording HUD for " .. player.Name
