local MouseButtonEvent = require("ui.input_events.MouseButtonEvent")

---@class ui.MouseDownEvent : ui.MouseButtonEvent
---@operator call: ui.MouseDownEvent
local MouseDownEvent = MouseButtonEvent + {}

function MouseDownEvent:trigger()
	self.current_target:onMouseDown(self)
end

return MouseDownEvent
