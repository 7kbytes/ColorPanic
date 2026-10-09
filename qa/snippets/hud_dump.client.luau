--# selene: allow(global_usage)
-- QA only. Client command bar: returns the lines recorded by hud_recorder.client.luau.
-- Set LAST to a number to return only the last N lines.
local LAST: number? = nil
local log = _G.hudlog or {}
local first = if LAST then math.max(1, #log - LAST + 1) else 1
local lines = {}
for i = first, #log do
	table.insert(lines, log[i])
end
return game:GetService("Players").LocalPlayer.Name .. "\n" .. table.concat(lines, "\n")
