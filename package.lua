local lua_package = package
local package = {}

local lfs = love and love.filesystem

local os_ext = {
	Windows = "dll",
	Linux = "so",
	OSX = "dylib",
}

local ext = os_ext[jit.os]

function package.reset()
	local added = "?.lua;?/init.lua"
	local addedc = "?." .. ext
	if lfs then
		lfs.setRequirePath(added)
		lfs.setCRequirePath(addedc)
	end
	lua_package.path = added
	lua_package.cpath = addedc
end

---@param path string
function package.add(path)
	local added = (";path/?.lua;path/?/init.lua"):gsub("path", path)
	if lfs then
		lfs.setRequirePath(lua_package.path .. added)
	end
	lua_package.path = lua_package.path .. added
end

---@param path string
function package.addc(path)
	local added = (";path/?." .. ext):gsub("path", path)
	if lfs then
		lfs.setCRequirePath(lua_package.cpath .. added)
	end
	lua_package.cpath = lua_package.cpath .. added
end

return package
