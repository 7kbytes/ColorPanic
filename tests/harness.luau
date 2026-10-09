-- Test harness for pure modules, run with Lune (see scripts/test.sh).
--
-- Game modules use Roblox-style requires (script.Parent.X, game:GetService(...)). This
-- harness reads the Rojo sourcemap and loads each module with fake `script` and `game`
-- objects that resolve those requires to the real files. Only pure modules can run here;
-- anything that touches real Roblox services or instances fails.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")

local SOURCEMAP_PATH = "sourcemap.json"

type Node = {
	name: string,
	className: string,
	filePaths: { string }?,
	children: { Node }?,
}

local root: Node = serde.decode("json", fs.readFile(SOURCEMAP_PATH))

local Harness = {}

-- Fake instances ----------------------------------------------------------------------

local proxyNode = setmetatable({}, { __mode = "k" }) -- proxy -> node
local proxyParent = setmetatable({}, { __mode = "k" }) -- proxy -> parent proxy

local makeProxy: (node: Node, parent: any) -> any

local function findChild(node: Node, name: string): Node?
	for _, child in node.children or {} do
		if child.name == name then
			return child
		end
	end
	return nil
end

local function fullName(proxy: any): string
	local parts = {}
	local current = proxy
	while current and proxyParent[current] do
		table.insert(parts, 1, proxyNode[current].name)
		current = proxyParent[current]
	end
	return "game." .. table.concat(parts, ".")
end

makeProxy = function(node: Node, parent: any): any
	local proxy = {}
	proxyNode[proxy] = node
	proxyParent[proxy] = parent
	local methods = {
		GetService = function(self, name: string)
			local child = findChild(proxyNode[self], name)
			assert(child, "Harness: no service " .. name .. " in the sourcemap")
			return makeProxy(child, self)
		end,
		FindFirstChild = function(self, name: string)
			local child = findChild(proxyNode[self], name)
			return if child then makeProxy(child, self) else nil
		end,
		WaitForChild = function(self, name: string)
			local child = findChild(proxyNode[self], name)
			assert(child, "Harness: WaitForChild would hang on " .. name)
			return makeProxy(child, self)
		end,
	}
	return setmetatable(proxy, {
		__index = function(self, key: string)
			if key == "Parent" then
				return proxyParent[self]
			elseif key == "Name" then
				return proxyNode[self].name
			elseif key == "ClassName" then
				return proxyNode[self].className
			elseif methods[key] then
				return methods[key]
			end
			local child = findChild(proxyNode[self], key)
			assert(child, string.format("Harness: %s has no child %s", fullName(self), key))
			return makeProxy(child, self)
		end,
		__tostring = function(self)
			return fullName(self)
		end,
	})
end

local game = makeProxy(root, nil)

-- Module loading ----------------------------------------------------------------------

local cache: { [string]: any } = {}

local function requireProxy(proxy: any): any
	local node = proxyNode[proxy]
	assert(node, "Harness: require expects a module instance")
	local path: string? = nil
	for _, filePath in node.filePaths or {} do
		if string.match(filePath, "%.luau?$") then
			path = filePath
		end
	end
	assert(path, "Harness: " .. fullName(proxy) .. " has no script file")

	if cache[path] == nil then
		local env = setmetatable({
			script = proxy,
			game = game,
			require = requireProxy,
		}, { __index = _G })
		local chunk = luau.load(fs.readFile(path), { debugName = path, environment = env })
		cache[path] = chunk()
	end
	return cache[path]
end

-- Loads a module by its DataModel path, e.g. "ServerScriptService.Server.RoundDirector".
function Harness.requireModule(dataModelPath: string): any
	local current = game
	for part in string.gmatch(dataModelPath, "[^%.]+") do
		current = current[part]
	end
	return requireProxy(current)
end

-- A seeded stand-in for Roblox's Random, exposing only NextInteger.
function Harness.fakeRandom(seed: number): any
	local state = seed % 2147483647
	if state <= 0 then
		state += 2147483646
	end
	return {
		NextInteger = function(_self, min: number, max: number): number
			state = (state * 48271) % 2147483647
			return min + (state % (max - min + 1))
		end,
	}
end

-- Tests -------------------------------------------------------------------------------

type Test = { name: string, fn: () -> () }

local tests: { Test } = {}
local currentGroup = ""

function Harness.describe(name: string, fn: () -> ())
	local previous = currentGroup
	currentGroup = if previous == "" then name else previous .. " > " .. name
	fn()
	currentGroup = previous
end

function Harness.it(name: string, fn: () -> ())
	table.insert(tests, { name = currentGroup .. " > " .. name, fn = fn })
end

local function show(value: any): string
	if type(value) == "table" then
		local parts = {}
		for k, v in value do
			table.insert(parts, tostring(k) .. "=" .. tostring(v))
		end
		return "{" .. table.concat(parts, ", ") .. "}"
	end
	return tostring(value)
end

function Harness.expect(actual: any)
	return {
		toBe = function(expected: any)
			if actual ~= expected then
				error(string.format("expected %s, got %s", show(expected), show(actual)), 2)
			end
		end,
		toBeCloseTo = function(expected: number, epsilon: number?)
			if math.abs(actual - expected) > (epsilon or 1e-9) then
				error(string.format("expected about %s, got %s", show(expected), show(actual)), 2)
			end
		end,
		toBeAtLeast = function(minimum: number)
			if actual < minimum then
				error(string.format("expected at least %s, got %s", show(minimum), show(actual)), 2)
			end
		end,
		toThrow = function()
			if pcall(actual) then
				error("expected the function to throw", 2)
			end
		end,
	}
end

-- Runs every registered test and returns the number of failures.
function Harness.run(): number
	local failures = 0
	for _, test in tests do
		local ok, err = pcall(test.fn)
		if ok then
			print("  PASS  " .. test.name)
		else
			failures += 1
			print("  FAIL  " .. test.name .. "\n        " .. tostring(err))
		end
	end
	print(string.format("\n%d passed, %d failed", #tests - failures, failures))
	return failures
end

return Harness
