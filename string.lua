local table_util = require("table_util")

---@param s string
---@return string
function string.trim(s)
	return s:match("^%s*(.-)%s*$")
end

---@param s string
---@param div string
---@return table
function string.split(s, div)
	local out = {}

	local pos = 0
	for a, b in function() return s:find(div, pos, true) end do
		out[#out + 1] = s:sub(pos, a - 1)
		pos = b + 1
	end
	out[#out + 1] = s:sub(pos)

	return out
end

---@param d string
---@return function
local function next_split(d)
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

return string
