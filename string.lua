local table_util = require("table_util")

---@param s string
---@return string
function string.trim(s)
	return s:match("^%s*(.-)%s*$")
end

---@param s string
---@param div string
---@return string[]
function string.split(s, div)
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
---@return function
local function next_split(d)
	---@param s string
	---@param p integer
	return function(s, p)
		if not p then
			return
		end
		local a, b = s:find(d, p, true)
		if not a then
			return false, s:sub(p)
		end
		return b + 1, s:sub(p, a - 1)
	end
end
next_split = table_util.cache(next_split)

---@param s string
---@param d string
---@return function
---@return string
---@return number
function string.isplit(s, d)
	return next_split(d), s, 1
end

---@param s string
---@param t table
---@param pattern string
---@return string
---@return table
function string.tpreformat(s, t, pattern)
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
function string.tformat(s, t, pattern)
	local _s, values = string.tpreformat(s, t, pattern or "%s")
	return _s:format(unpack(values))
end

return string
