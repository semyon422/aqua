local fonts = {}

local instances = {}

fonts.getFont = function(path, size)
	if not (instances[path] and instances[path][size]) then
		instances[path] = instances[path] or {}
		instances[path][size] = love.graphics.newFont(path, size)
	end
	return instances[path][size]
end

return fonts