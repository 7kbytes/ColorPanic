--# selene: allow(global_usage)
-- QA only. Client command bar: logs every HUD change with server time into _G.hudlog.
local player = game:GetService("Players").LocalPlayer
_G.hudlog = {}
_G.hudRecorderRunning = true
-- A badge's text, or "(hidden)" while the badge is not shown.
local function piece(hud: any, name: string): string
	local panel = hud:FindFirstChild(name)
	if not (panel and panel.Visible) then
		return name .. " (hidden)"
	end
	return name .. " " .. panel.Body.Text.Text
end
task.spawn(function()
	local last = ""
	while _G.hudRecorderRunning do
		local hud = player.PlayerGui:FindFirstChild("HUD")
		if hud then
			local line = table.concat({
				hud.Status.Text,
				piece(hud, "RoundBadge"),
				piece(hud, "TargetCard"),
				piece(hud, "PlayersBadge"),
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
