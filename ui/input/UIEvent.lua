local class = require("class")

---@class ui.UIEvent
---@operator call: ui.UIEvent
---@field target ui.Node?
---@field current_target ui.Node?
---@field control_pressed boolean
---@field shift_pressed boolean
---@field alt_pressed boolean
---@field super_pressed boolean
local UIEvent = class()

---@param modifiers {control: boolean, shift: boolean, alt: boolean, super: boolean}
function UIEvent:new(modifiers)
	self.stop = false
	self.control_pressed = modifiers.control
	self.shift_pressed = modifiers.shift
	self.alt_pressed = modifiers.alt
	self.super_pressed = modifiers.super
end

function UIEvent:stopPropagation()
	self.stop = true
end

---@return boolean?
function UIEvent:trigger() end

return UIEvent
