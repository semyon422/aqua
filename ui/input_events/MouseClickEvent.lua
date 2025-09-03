local MouseButtonEvent = require("ui.input_events.MouseButtonEvent")

---@class ui.MouseClickEvent : ui.MouseButtonEvent
---@operator call: ui.MouseClickEvent
local MouseClickEvent = MouseButtonEvent + {}

function MouseClickEvent:trigger()
	self.current_target:onMouseClick(self)
end

return MouseClickEvent
