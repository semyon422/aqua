local MouseButtonEvent = require("ui.input.events.MouseButtonEvent")

---@class ui.DragEndEvent : ui.MouseButtonEvent
---@operator call: ui.DragEndEvent
local DragEndEvent = MouseButtonEvent + {}

function DragEndEvent:trigger()
	return self.current_target:onDragEnd(self)
end

return DragEndEvent
