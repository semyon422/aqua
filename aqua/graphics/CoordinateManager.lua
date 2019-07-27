local CS = require("aqua.graphics.CS")

local CoordinateManager = {}

CoordinateManager.fontBaseUnit = 720
CoordinateManager.cses = {}

CoordinateManager.getCS = function(self, bx, by, rx, ry, binding)
	local csString = ("%s/%s/%s/%s/%s"):format(bx, by, rx, ry, binding)
	local cses = self.cses
	if cses[csString] then
		return cses[csString]
	end
	
	local screenWidth = love.graphics.getWidth()
	local screenHeight = love.graphics.getHeight()
	cses[csString] = CS:new({
		bx = bx,
		by = by,
		rx = rx,
		ry = ry,
		binding = binding,
		baseOne = self.fontBaseUnit,
		screenWidth = screenWidth,
		screenHeight = screenHeight
	})
	cses[csString]:reload()
	return cses[csString]
end

CoordinateManager.reload = function(self)
	local screenWidth = love.graphics.getWidth()
	local screenHeight = love.graphics.getHeight()
	
	for _, cs in pairs(self.cses) do
		cs.screenWidth = screenWidth
		cs.screenHeight = screenHeight
		cs:reload()
	end
end

return CoordinateManager
