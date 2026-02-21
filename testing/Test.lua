local class = require("class")
local table_util = require("table_util")
local stbl = require("stbl")

---@class testing.T
---@operator call: testing.T
---@field [integer] string?
---@field name string?
---@field path string?
local Test = class()

---@generic T
---@param cond? T
---@param err? any
---@param ... any
---@return T
---@return any ...
function Test:assert(cond, err, ...)
	if cond then
		return cond
	end

	local level = 2
	local info = debug.getinfo(level, "Sl")

	if info and (info.short_src == "[C]" or info.short_src:match("Testing%.lua")) and self.path then
		local i = 1
		while true do
			local stack_info = debug.getinfo(i, "Sl")
			if not stack_info then break end
			if stack_info.short_src == self.path or stack_info.source == "@" .. self.path then
				info = stack_info
				break
			end
			i = i + 1
		end
	end

	local src = info and info.short_src or (self.path or "unknown")
	local line = info and info.currentline or -1

	table.insert(self, ("%s:%s: assertion failed%s, got %s"):format(
		src,
		line,
		err and (" with error '%s'"):format(err) or "",
		cond
	))

	return cond
end

---@param v any
---@return any
local function format_got_expected(v)
	if type(v) ~= "table" then
		return v
	end
	stbl.allow_nan_inf = true
	local s = stbl.encode(v, nil, true)
	stbl.allow_nan_inf = false
	return s
end

---@param a string
---@param b string
---@return string
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

---@param expected string
---@param got string
---@return string
---@return string
local function get_dual_diff(expected, got)
	local len1, len2 = #expected, #got
	---@type integer[][]
	local matrix = {}

	for i = 0, len1 do
		matrix[i] = {}
		for j = 0, len2 do matrix[i][j] = 0 end
	end

	for i = 1, len1 do
		for j = 1, len2 do
			if expected:sub(i, i) == got:sub(j, j) then
				matrix[i][j] = matrix[i - 1][j - 1] + 1
			else
				matrix[i][j] = math.max(matrix[i - 1][j], matrix[i][j - 1])
			end
		end
	end

	local res_expected = {}
	local res_got = {}
	local i, j = len1, len2

	local RESET = "\27[0m"
	local RED = "\27[31m"
	local GREEN = "\27[32m"

	while i > 0 or j > 0 do
		if i > 0 and j > 0 and expected:sub(i, i) == got:sub(j, j) then
			local char = expected:sub(i, i)
			table.insert(res_expected, 1, char)
			table.insert(res_got, 1, char)
			i, j = i - 1, j - 1
		elseif j > 0 and (i == 0 or matrix[i][j - 1] >= matrix[i - 1][j]) then
			table.insert(res_got, 1, GREEN .. got:sub(j, j) .. RESET)
			j = j - 1
		else
			table.insert(res_expected, 1, RED .. expected:sub(i, i) .. RESET)
			i = i - 1
		end
	end

	return table.concat(res_expected), table.concat(res_got)
end

---@param cond any?
---@param got any?
---@param expected any?
---@param level integer?
---@param msg any?
---@return any?
function Test:expected_assert(cond, got, expected, level, msg)
	if cond then
		return cond
	end

	level = level or 2
	local info = debug.getinfo(level, "Sl")

	if info and (info.short_src == "[C]" or info.short_src:match("Testing%.lua")) and self.path then
		-- Try to find the line in the stack that belongs to self.path
		local i = 1
		while true do
			local stack_info = debug.getinfo(i, "Sl")
			if not stack_info then break end
			if stack_info.short_src == self.path or stack_info.source == "@" .. self.path then
				info = stack_info
				break
			end
			i = i + 1
		end
	end

	got = format_got_expected(got)
	expected = format_got_expected(expected)

	local colored_expected, colored_got = tostring(expected), tostring(got)
	if #colored_expected * #colored_got <= 1e5 then
		colored_expected, colored_got = get_dual_diff(tostring(colored_expected), tostring(colored_got))
	end

	local src = info and info.short_src or (self.path or "unknown")
	local line = info and info.currentline or -1

	---@type string[]
	local out = {}
	table.insert(out, ("%s:%s:%s"):format(src, line, msg and (" " .. tostring(msg)) or ""))
	if self.name then
		out[1] = ("%s (%s)"):format(out[1], self.name)
	end
	table.insert(out, "---- expected")
	table.insert(out, colored_expected)
	table.insert(out, "---- got")
	table.insert(out, colored_got)
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
---@param num_args integer?
---@return function
local function build_method(f, num_args)
	num_args = num_args or 2
	return function(self, got, expected, ...)
		local msg
		if select("#", ...) > num_args - 2 then
			msg = select(num_args - 2 + 1, ...)
		end
		return self:expected_assert(f(got, expected, ...), got, expected, 3, msg)
	end
end

Test.eq = build_method(function(a, b) return a == b end)
Test.ne = build_method(function(a, b) return a ~= b end)
Test.raweq = build_method(function(a, b) return rawequal(a, b) end)
Test.rawne = build_method(function(a, b) return not rawequal(a, b) end)
Test.lt = build_method(function(a, b) return a < b end)
Test.le = build_method(function(a, b) return a <= b end)

Test.aeq = build_method(function(a, b, eps)
	if type(a) == "number" and type(b) == "number" then
		return math.abs(a - b) < eps
	end
	return a == b
end, 3)

Test.teq = build_method(table_util.equal)
Test.tdeq = build_method(table_util.deepequal)

---@param f any
---@param ... any
---@return string?
function Test:has_error(f, ...)
	---@type boolean, string
	local ok, err = pcall(f, ...)
	self:expected_assert(not ok, "no error", "error", 3)
	if not ok then
		return err:match("^.-:.-: ([^\n]+)\n?.*$")
	end
end

---@param f any
---@param ... any
---@return boolean
function Test:has_not_error(f, ...)
	---@type boolean, string
	local ok, err = pcall(f, ...)
	self:expected_assert(ok, "error", "no error", 3)
	return ok
end

return Test
