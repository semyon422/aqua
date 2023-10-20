local lua_package = package
local package = {}

local lfs = love and love.filesystem

function package.reset()
	if lfs then
		lfs.setRequirePath("")
		lfs.setCRequirePath("")
	end
	lua_package.path = ""
	lua_package.cpath = ""
	package.add(".")
end

---@param path string
function package.add(path)
	local added = (";path/?.lua;path/?/init.lua"):gsub("path", path)
	if lfs then
		lfs.setRequirePath(lua_package.path .. added)
	end
	lua_package.path = lua_package.path .. added
end

local ext = jit.os == "Windows" and "dll" or "so"

---@param path string
function package.addc(path)
	local added = (";path/?." .. ext):gsub("path", path)
	if lfs then
		lfs.setCRequirePath(lua_package.cpath .. added)
	end
	lua_package.cpath = lua_package.cpath .. added
end

return package

