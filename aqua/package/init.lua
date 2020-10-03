local _package = package
local path = package.path
local cpath = package.cpath

local package = {}

local paths = {}

package.reset = function()
	_package.path = path .. ";./?/init.lua;./?/?.lua"
	_package.cpath = cpath
	paths = {}
end

package.add = function(path)
	if paths[path] then return end

	_package.path = _package.path .. (";./path/?.lua;./path/?/init.lua;./path/?/?.lua"):gsub("path", path)
	_package.cpath = _package.cpath .. (";./path/?.dll;./path/?/?.dll"):gsub("path", path)
	_package.cpath = _package.cpath .. (";./path/?.so;./path/?/?.so"):gsub("path", path)
end

package.reset()

return package
