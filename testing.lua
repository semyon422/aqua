local testing = {}

testing.blacklist = {}

---@param a table
---@param b table
---@return boolean
local function sort_files(a, b)
	if a.type == b.type then
		return a.path < b.path
	end
	return a.type == "file"
end

---@param dpath string
---@param pattern string
local function lookup(dpath, pattern)
	for _, item in ipairs(testing.blacklist) do
		if dpath:find(item, 1, true) then
			return
		end
	end

	local items = love.filesystem.getDirectoryItems(dpath)

	local file_infos = {}

	for _, name in ipairs(items) do
		local path = dpath .. name
		local info = love.filesystem.getInfo(path)
		local t = info.type

		if t == "file" and name:find(pattern) or t == "directory" then
			table.insert(file_infos, {
				path = path,
				type = t
			})
		end
	end

	table.sort(file_infos, sort_files)

	for _, item in ipairs(file_infos) do
		if item.type == "file" then
			coroutine.yield(item.path)
		elseif item.type == "directory" then
			lookup(item.path .. "/", pattern)
		end
	end
end

---@param path string
---@param pattern string
---@return function
local function iter_files(path, pattern)
	return coroutine.wrap(function()
		lookup(path, pattern)
	end)
end

--------------------------------------------------------------------------------

local Test = {}
Test.__index = Test

---@param cond any?
---@param got any?
---@param expected any?
---@return any?
function Test:assert(cond, got, expected)
	if cond then
		return cond
	end
	local line = debug.getinfo(2, "Sl")

	table.insert(self, ("%s:%s: %s expected, got %s"):format(
		line.short_src,
		line.currentline,
		expected, got
	))
end

---@param got any?
---@param _type string
function Test:typeof(got, _type)
	self:eq(type(got), _type)
end

---@param f function
---@return function
local function build_method(f)
	return function(self, got, expected)
		return self:assert(f(got, expected), got, expected)
	end
end

Test.eq = build_method(function(a, b) return a == b end)
Test.ne = build_method(function(a, b) return a ~= b end)
Test.lt = build_method(function(a, b) return a < b end)
Test.le = build_method(function(a, b) return a <= b end)

--------------------------------------------------------------------------------

local Bench = {}
Bench.__index = Bench

function Bench:reset()
	self.start_time = love.timer.getTime()
end

--------------------------------------------------------------------------------

---@param path string
---@return table
local function get_mod(path)
	local data = assert(love.filesystem.read(path))
	local f = assert(load(data, "@" .. path))
	return f()
end

---@param test table
---@param t table
local function run_tests(test, t)
	local errors = #t
	for k, v in pairs(test) do
		v(t)
		if errors ~= #t then
			errors = #t
			t.fail = t.fail + 1
		end
		t.total = t.total + 1
	end
end

local max_duration = 0.1
local max_count = 2 ^ 20

---@param f function
---@return number
---@return number
local function run_bench(f)
	local b = setmetatable({}, Bench)

	local N = 1

	local dt = 0
	b:reset()
	while dt < max_duration and N < max_count do
		N = N * 2
		f(b, N)
		dt = love.timer.getTime() - b.start_time
	end

	return dt, N
end

---@param bench table
local function run_benchs(bench)
	for k, v in pairs(bench) do
		local dt, N = run_bench(v)
		print(("%s: %s"):format(k, dt / N))
	end
end

function testing.test()
	local t = setmetatable({
		total = 0,
		fail = 0,
	}, Test)

	for path in iter_files("", "_test%.lua$") do
		io.write(path)
		io.flush()

		local mod = get_mod(path)

		local start_time = love.timer.getTime()
		run_tests(mod, t)
		local dt = love.timer.getTime() - start_time

		print((": %0.3fs"):format(dt))
	end

	for _,  line in ipairs(t) do
		print(line)
	end

	if t.fail == 0 then
		print("OK: " .. t.total)
	else
		print(("FAIL: %d / %d"):format(t.fail, t.total))
	end
end

function testing.bench()
	for path in iter_files("", "_bench%.lua$") do
		local mod = get_mod(path)
		run_benchs(mod)
	end
end

return testing
