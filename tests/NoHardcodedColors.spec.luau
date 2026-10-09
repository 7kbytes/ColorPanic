-- Colors, hexes and shapes may only be defined in src/shared/Config.luau. This scans every
-- other source file for literal color values and shape names.

local fs = require("@lune/fs")

local Harness = require("./harness")
local describe, it, expect = Harness.describe, Harness.it, Harness.expect

local SOURCE_ROOT = "src"

-- Files allowed to contain the patterns below, and why.
local ALLOWED: { [string]: { [string]: boolean } } = {
	-- The palette itself.
	["src/shared/Config.luau"] = { color = true, shape = true },
	-- Declares the ShapeId type, which has to name the six shapes.
	["src/shared/Types.luau"] = { shape = true },
}

local COLOR_PATTERNS = {
	"Color3%.fromRGB%(%s*%d", -- Color3.fromRGB(235, ...)
	"Color3%.new%(%s*[%d%.]", -- Color3.new(0.9, ...)
	"Color3%.fromHex%(%s*[\"']", -- Color3.fromHex("#...")
	"Color3%.fromHSV%(%s*[%d%.]", -- Color3.fromHSV(0.1, ...)
	"BrickColor%.new%(", -- BrickColor.new("Bright red")
	"[\"']#%x%x%x%x%x%x[\"']", -- "#E8383D"
}

local SHAPES = { "heart", "triangle", "star", "circle", "square", "diamond" }

local function listLuauFiles(dir: string, out: { string })
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			listLuauFiles(path, out)
		elseif string.match(name, "%.luau$") then
			table.insert(out, path)
		end
	end
end

local function findViolations(): { string }
	local files = {}
	listLuauFiles(SOURCE_ROOT, files)
	table.sort(files)
	local violations = {}
	for _, path in files do
		local allowed = ALLOWED[path] or {}
		local lineNumber = 0
		for line in string.gmatch(fs.readFile(path) .. "\n", "([^\n]*)\n") do
			lineNumber += 1
			local code = string.gsub(line, "%-%-.*$", "") -- ignore comments
			if not allowed.color then
				for _, pattern in COLOR_PATTERNS do
					if string.find(code, pattern) then
						table.insert(
							violations,
							string.format("%s:%d color: %s", path, lineNumber, line)
						)
					end
				end
			end
			if not allowed.shape then
				for _, shape in SHAPES do
					if string.find(code, "[\"']" .. shape .. "[\"']") then
						table.insert(
							violations,
							string.format("%s:%d shape: %s", path, lineNumber, line)
						)
					end
				end
			end
		end
	end
	return violations
end

describe("No hardcoded colors or shapes outside Config", function()
	it("finds no literal colors or shape names in src/", function()
		local violations = findViolations()
		if #violations > 0 then
			error("Hardcoded values found:\n" .. table.concat(violations, "\n"))
		end
		expect(#violations).toBe(0)
	end)
end)
