local ls = require("ls")
local table_util = require("table_util")
local class = require("class")

local testing = {}

testing.blacklist = {}

---@param dir string
---@param pattern string
local function lookup(dir, pattern)
	for _, item in ipairs(testing.blacklist) do
		if dir:find(item, 1, true) then
			return
		end
	end

	for name, t in ls.iter(dir) do
		local path = dir .. name
		if t == "file" and name:find(pattern) then
			coroutine.yield(path)
		elseif t == "directory" then
			lookup(path .. "/", pattern)
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

local Test = class()

Test.total = 0
Test.fail = 0

---@param cond any?
---@return any?
function Test:assert(cond)
	if cond then
		return cond
	end
	local line = debug.getinfo(2, "Sl")

	table.insert(self, ("%s:%s: assertion failed, got %s"):format(
		line.short_src,
		line.currentline,
		cond
	))
end

---@param cond any?
---@param got any?
---@param expected any?
---@return any?
function Test:expected_assert(cond, got, expected)
	if cond then
		return cond
	end
	local line = debug.getinfo(2, "Sl")

	table.insert(self, ("%s:%s:\n---- expected\n%s\n---- got\n%s\n---- end"):format(
		line.short_src,
		line.currentline,
		expected, got
	))
end

---@param got any?
---@param _type string
function Test:typeof(got, _type)
	return self:eq(type(got), _type)
end

---@param f function
---@return function
local function build_method(f)
	return function(self, got, expected)
		return self:expected_assert(f(got, expected), got, expected)
	end
end

Test.eq = build_method(function(a, b) return a == b end)
Test.ne = build_method(function(a, b) return a ~= b end)
Test.lt = build_method(function(a, b) return a < b end)
Test.le = build_method(function(a, b) return a <= b end)

Test.teq = build_method(table_util.equal)
Test.tdeq = build_method(table_util.deepequal)

function Test:has_error(f, ...)
	local ok = pcall(f, ...)
	return self:eq(ok, false)
end

--------------------------------------------------------------------------------

function testing.get_time()
	error("not implemented")
end

local Bench = class()

function Bench:reset()
	self.start_time = testing.get_time()
end

--------------------------------------------------------------------------------

---@param test table
---@param t table
local function run_tests(test, t)
	local errors = #t
	for _, v in pairs(test) do
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
	local b = Bench()

	local N = 1

	local dt = 0
	b:reset()
	while dt < max_duration and N < max_count do
		N = N * 2
		f(b, N)
		dt = testing.get_time() - b.start_time
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
	local t = Test()

	for path in iter_files("", "_test%.lua$") do
		io.write(path)
		io.flush()

		local start_time = testing.get_time()
		local mod = dofile(path)
		if mod then
			run_tests(mod, t)
		end
		local dt = testing.get_time() - start_time

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
		local mod = dofile(path)
		run_benchs(mod)
	end
end

return testing
