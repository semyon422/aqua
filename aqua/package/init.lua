local _package = package
local path = package.path

local package = {}

package.reset = function()
	_package.path = path .. ";./?/init.lua;./?/?.lua"
end

package.addPath = function(path)
	_package.path = _package.path .. (";./path/?.lua;./path/?/init.lua;./path/?/?.lua"):gsub("path", path)
end

package.reset()

return package
