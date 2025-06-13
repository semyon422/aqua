local class = require("class")

---@class ui.Fonts
---@operator call: ui.Fonts
---@field store {[string]: love.Font}
local Fonts = class()

function Fonts:new()
	self.store = {}
end

---@param name string
---@param font love.Font
function Fonts:add(name, font)
	self.store[name] = font
end

---@param name string
---@return boolean
function Fonts:isFontExists(name)
	return self.store[name] ~= nil
end

---@param name string
---@param size number
---@return love.Font
---@return number scale
function Fonts:get(name, size)
	local font = self.store[name]
	local scale = (100 / font:getHeight()) * (size / 100)
	return font, scale
end

return Fonts
