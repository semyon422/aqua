local fonts = {}

local instances = {}

local graphics = require("love.graphics")
local newFont = graphics.newFont
fonts.getFont = function(path, size)
	if not (instances[path] and instances[path][size]) then
		instances[path] = instances[path] or {}
		instances[path][size] = newFont(path, size)
	end
	return instances[path][size]
end

return fonts