local path_util = {}

---@param s string
---@param c string?
---@return string
function path_util.fix_illegal(s, c)
	return (s:gsub('[/\\?%*:|"<>]', c or "_"))
end

---@param ... string?
---@return string
function path_util.join(...)
	local t = {}
	for i = 1, select("#", ...) do
		local p = select(i, ...)
		if p then
			p = tostring(p):gsub("\\", "/"):gsub("/[^/]-/%.%./", "/")
			table.insert(t, p)
		end
	end
	return table.concat(t, "/")
end

return path_util
