local requirePath = love.filesystem.getRequirePath()
local cRequirePath = love.filesystem.getCRequirePath()

local package = {}

package.reset = function()
	love.filesystem.setRequirePath(requirePath)
	love.filesystem.setCRequirePath(cRequirePath)
end

package.add = function(path)
	local requirePath = love.filesystem.getRequirePath()
    love.filesystem.setRequirePath(requirePath .. (";path/?.lua;path/?/init.lua"):gsub("path", path))

	local cRequirePath = love.filesystem.getCRequirePath()
    love.filesystem.setCRequirePath(cRequirePath .. (";path/?.dll"):gsub("path", path))
    love.filesystem.setCRequirePath(cRequirePath .. (";path/?.so"):gsub("path", path))
end

return package

