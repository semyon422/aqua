local MouseButtonEvent = require("ui.input.events.MouseButtonEvent")

---@class ui.MouseUpEvent : ui.MouseButtonEvent
---@operator call: ui.MouseUpEvent
local MouseUpEvent = MouseButtonEvent + {}

function MouseUpEvent:trigger()
	return self.current_target:onMouseUp(self)
end

return MouseUpEvent
