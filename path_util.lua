local path_util = {}

---@param s string
---@param c string?
---@return string
function path_util.fix_illegal(s, c)
	return (s:gsub('[/\\?%*:|"<>]', c or "_"))
end

return path_util
