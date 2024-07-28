local ls = require("ls")
local table_util = require("table_util")
local stbl = require("stbl")
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

local function format_got_expected(v)
	if type(v) ~= "table" then
		return v
	end
	return stbl.encode(v)
end

local function string_diff(a, b)
	local out = {}
	if #a ~= #b then
		table.insert(out, ("size: %s, %s"):format(#a, #b))
	end
	for i = 1, math.min(#a, #b) do
		local ca, cb = a:sub(i, i), b:sub(i, i)
		if ca ~= cb then
			table.insert(out, ("pos: %s"):format(i))
			table.insert(out, ("chars: %q (%s), %q (%s)"):format(ca, ca:byte(), cb, cb:byte()))
			break
		end
	end
	return table.concat(out, ", ")
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

	got = format_got_expected(got)
	expected = format_got_expected(expected)

	local out = {}
	table.insert(out, ("%s:%s:"):format(line.short_src, line.currentline))
	table.insert(out, "---- expected")
	table.insert(out, tostring(expected))
	table.insert(out, "---- got")
	table.insert(out, tostring(got))
	table.insert(out, "---- end")

	local tg, te = type(got), type(expected)
	if tg == te and tg == "string" then
		table.insert(out, "---- " .. string_diff(expected, got))
	end

	table.insert(self, table.concat(out, "\n"))
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
Test.raweq = build_method(function(a, b) return rawequal(a, b) end)
Test.rawne = build_method(function(a, b) return not rawequal(a, b) end)
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
---@param method_pattern string?
local function run_tests(test, t, method_pattern)
	local errors = #t
	for method, v in pairs(test) do
		if not method_pattern or method:match(method_pattern) then
			v(t)
			if errors ~= #t then
				errors = #t
				t.fail = t.fail + 1
			end
			t.total = t.total + 1
		end
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

---@param file_pattern string?
---@param method_pattern string?
function testing.test(file_pattern, method_pattern)
	local t = Test()

	for path in iter_files("", "_test%.lua$") do
		if not file_pattern or path:match(file_pattern) then
			io.write(path)
			io.flush()

			local start_time = testing.get_time()
			local mod = dofile(path)
			if mod then
				run_tests(mod, t, method_pattern)
			end
			local dt = testing.get_time() - start_time

			print((": %0.3fs"):format(dt))
		end
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
