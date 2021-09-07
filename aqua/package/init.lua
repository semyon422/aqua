local requirePath = love.filesystem.getRequirePath()
local cRequirePath = love.filesystem.getCRequirePath()

local package = {}

package.reset = function()
	love.filesystem.setRequirePath(requirePath)
	love.filesystem.setCRequirePath(cRequirePath)
end

local ext = jit.os == "Windows" and "dll" or "so"
package.add = function(path)
    love.filesystem.setRequirePath(love.filesystem.getRequirePath() .. (";path/?.lua;path/?/init.lua"):gsub("path", path))
    love.filesystem.setCRequirePath(love.filesystem.getCRequirePath() .. (";path/?." .. ext):gsub("path", path))
end

return package

