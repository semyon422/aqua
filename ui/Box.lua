local class = require("class")

---@class ui.Box
---@operator call: ui.Box
local Box = class()

function Box:new()
	self.x = 0
	self.y = 0
	self.width = 0
	self.height = 0
	self.transform = love.math.newTransform()
end

---@param x number
---@param y number
---@param width number
---@param height number
---@param ui_scale number?
function Box:update(x, y, width, height, ui_scale)
	ui_scale = ui_scale or 1
	self.x = x
	self.y = y
	self.width = width
	self.height = height
	self.transform:setTransformation(x * ui_scale, y * ui_scale, 0, ui_scale, ui_scale, 0, 0)
end

---@return number
---@return number
function Box:getDimensions()
	return self.width, self.height
end

return Box
