-- Runs every tests/*.spec.luau file. Use scripts/test.sh, which builds the sourcemap first.

local fs = require("@lune/fs")
local process = require("@lune/process")

local Harness = require("./harness")

local specs = {}
for _, name in fs.readDir("tests") do
	if string.match(name, "%.spec%.luau$") then
		table.insert(specs, name)
	end
end
table.sort(specs)

for _, name in specs do
	require("./" .. string.gsub(name, "%.luau$", ""))
end

process.exit(if Harness.run() == 0 then 0 else 1)
