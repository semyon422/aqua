local path_util = {}

---@param s string
---@param c string?
---@return string
function path_util.fix_illegal(s, c)
	return (s:gsub('[/\\?%*:|"<>]', c or "_"))
end

---@param s string
---@return string
function path_util.fix_separators(s)
	return (s:gsub('[\\¥]', "/"))
end

---@param path string
---@return string
function path_util.dirname(path)
	path = path_util.fix_separators(path)
	local dir = path:match("^(.+)/[^/]+$")
	return dir or ""
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

---@param name string
---@param lower boolean?
---@return string?
function path_util.ext(name, lower)
	---@type string?
	local ext = name:match("^.+%.(.-)$")
	if ext and lower then
		ext = ext:lower()
	end
	return ext
end

---@param name string
---@return string
---@return string?
function path_util.name_ext(name)
	local _name, ext = name:match("^(.+)%.([^%.]-)$")
	if not _name then
		return name
	end
	return _name, ext
end

assert(table.concat({path_util.name_ext("file.zip")}, " ") == "file zip")
assert(table.concat({path_util.name_ext("file.zip.zip")}, " ") == "file.zip zip")
assert(table.concat({path_util.name_ext(".file")}, " ") == ".file")
assert(table.concat({path_util.name_ext("..file")}, " ") == ". file")
assert(table.concat({path_util.name_ext("...file")}, " ") == ".. file")
assert(table.concat({path_util.name_ext(".file.zip")}, " ") == ".file zip")

return path_util
