local path_util = {}

---@param s string
---@param c string?
---@return string
function path_util.fix_illegal(s, c)
	return (s:gsub('[/\\?%*:|"<>]', c or "_"))
end

---@param path string
---@return string
function path_util.eval_path(path)
	return (path:gsub("\\", "/"):gsub("/[^/]-/%.%./", "/"))
end

return path_util
