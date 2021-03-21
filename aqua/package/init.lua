local requirePath = love.filesystem.getRequirePath()
local cRequirePath = love.filesystem.getCRequirePath()
local _package = package
local path = package.path
local cpath = package.cpath

local package = {}

package.reset = function()
	love.filesystem.setRequirePath(requirePath)
	love.filesystem.setCRequirePath(cRequirePath)
	_package.path = path
	_package.cpath = cpath
end

package.add = function(path)
	local requirePath = love.filesystem.getRequirePath()
    love.filesystem.setRequirePath(requirePath .. (";path/?.lua;path/?/init.lua"):gsub("path", path))

	local cRequirePath = love.filesystem.getCRequirePath()
    love.filesystem.setCRequirePath(cRequirePath .. (";path/?.dll"):gsub("path", path))
    love.filesystem.setCRequirePath(cRequirePath .. (";path/?.so"):gsub("path", path))

	_package.path = _package.path .. (";./path/?.lua;./path/?/init.lua"):gsub("path", path)
	_package.cpath = _package.cpath .. (";./path/?.dll;./path/?/?.dll"):gsub("path", path)
	_package.cpath = _package.cpath .. (";./path/?.so;./path/?/?.so"):gsub("path", path)
end

package.reset()

return package

