-- QA only. Server command bar: the server log lines that matter for QA.
local KEEP = { "%[Match%]", "%[Elimination%]", "%[Reset%]", "%[QA%]", "%[Placement%]" }

local lines = {}
for _, entry in game:GetService("LogService"):GetLogHistory() do
	local keep = entry.messageType == Enum.MessageType.MessageWarning
		or entry.messageType == Enum.MessageType.MessageError
	for _, pattern in KEEP do
		if string.find(entry.message, pattern) then
			keep = true
		end
	end
	if keep then
		local prefix = if entry.messageType == Enum.MessageType.MessageError
			then "ERROR "
			elseif entry.messageType == Enum.MessageType.MessageWarning then "WARN "
			else ""
		table.insert(lines, prefix .. entry.message)
	end
end
return table.concat(lines, "\n")
