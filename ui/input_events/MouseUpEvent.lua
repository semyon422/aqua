local MouseButtonEvent = require("ui.input_events.MouseButtonEvent")

---@class ui.MouseUpEvent : ui.MouseButtonEvent
---@operator call: ui.MouseUpEvent
local MouseUpEvent = MouseButtonEvent + {}

function MouseUpEvent:trigger()
	self.current_target:onMouseUp(self)
end

return MouseUpEvent
