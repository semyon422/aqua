local MouseButtonEvent = require("ui.input_events.MouseButtonEvent")

---@class ui.DragEndEvent : ui.MouseButtonEvent
---@operator call: ui.DragEndEvent
local DragEndEvent = MouseButtonEvent + {}

function DragEndEvent:trigger()
	self.current_target:onDragEnd(self)
end

return DragEndEvent
