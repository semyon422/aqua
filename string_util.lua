local table_util = require("table_util")

local string_util = {}

---@param s string
---@return string
function string_util.trim(s)
	return s:match("^%s*(.-)%s*$")
end

---@param s string
---@param div string
---@return string[]
function string_util.split(s, div)
	local out = {}

	local pos = 0
	for a, b in function() return s:find(div, pos, true) end do
		table.insert(out, s:sub(pos, a - 1))
		pos = b + 1
	end
	table.insert(out, s:sub(pos))

	return out
end

---@param d string
---@return fun(s: string, p: string?): integer?, string?
local function next_split(d)
	---@param s string
	---@param p integer
	return function(s, p)
		if not p or p <= 0 then
			return
		end
		local a, b = s:find(d, p, true)
		if not a then
			return 0, s:sub(p)
		end
		return b + 1, s:sub(p, a - 1)
	end
end
next_split = table_util.cache(next_split)

---@param s string
---@param d string
---@return fun(s: string, p: string?): integer?, string?
---@return string
---@return number
function string_util.isplit(s, d)
	return next_split(d), s, 1
end

local function isplit_iter(s, d)
	local t = {}
	for _, _s in string_util.isplit(s, d) do
		table.insert(t, _s)
	end
	return table.concat(t, ",")
end

assert(isplit_iter("1 2 3", " ") == "1,2,3")
assert(isplit_iter(" 1 2 3 ", " ") == ",1,2,3,")
assert(isplit_iter(" ", " ") == ",")
assert(isplit_iter("  ", " ") == ",,")

---@param s string
---@param t table
---@param pattern string
---@return string
---@return table
function string_util.tpreformat(s, t, pattern)
	---@type any[]
	local values = {}
	local size = 0
	s = s:gsub("{([^{^}]+)}", function(key)
		size = size + 1
		values[size] = t[key]
		return pattern
	end)
	return s, values
end

---@param s string
---@param t table
---@param pattern string?
---@return string
function string_util.tformat(s, t, pattern)
	local _s, values = string_util.tpreformat(s, t, pattern or "%s")
	return _s:format(unpack(values))
end

return string_util
