local _package = package
local path = package.path

local package = {}

local paths = {}

package.reset = function()
	_package.path = path .. ";./?/init.lua;./?/?.lua"
	paths = {}
end

package.add = function(path)
	if paths[path] then return end
	
	_package.path = _package.path .. (";./path/?.lua;./path/?/init.lua;./path/?/?.lua"):gsub("path", path)
end

package.reset()

return package
