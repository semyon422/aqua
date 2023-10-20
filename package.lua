local requirePath = "?.lua;?/init.lua"
local cRequirePath = "./?.so"

local _package = package
local package = {}

local lfs = love.filesystem

function package.reset()
	lfs.setRequirePath(requirePath)
	lfs.setCRequirePath(cRequirePath)
	package.path = requirePath
	package.cpath = cRequirePath
end

---@param path string
function package.add(path)
	lfs.setRequirePath(lfs.getRequirePath() .. (";path/?.lua;path/?/init.lua"):gsub("path", path))
	_package.path = lfs.getRequirePath()
end

local ext = jit.os == "Windows" and "dll" or "so"

---@param path string
function package.addc(path)
	lfs.setCRequirePath(lfs.getCRequirePath() .. (";path/?." .. ext):gsub("path", path))
	_package.cpath = lfs.getCRequirePath()
end

return package

