local class = require("class")

---@class ui.UIEvent
---@operator call: ui.UIEvent
---@field target ui.IInputHandler?
---@field current_target ui.IInputHandler
---@field control_pressed boolean
---@field shift_pressed boolean
---@field alt_pressed boolean
---@field super_pressed boolean
local UIEvent = class()

function UIEvent:new()
	self.stop = false
	self.control_pressed = love.keyboard.isDown("lctrl", "rctrl")
	self.shift_pressed = love.keyboard.isDown("lshift", "rshift")
	self.alt_pressed = love.keyboard.isDown("lalt", "ralt")
	self.super_pressed = love.keyboard.isDown("lgui")
end

function UIEvent:stopPropagation()
	self.stop = true
end

---@return boolean?
function UIEvent:trigger() end

return UIEvent
