local class = require("class")
local table_util = require("table_util")
local stbl = require("stbl")

---@class testing.T
---@operator call: testing.T
---@field [integer] string?
local Test = class()

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

return Test
