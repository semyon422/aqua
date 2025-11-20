local MouseButtonEvent = require("ui.input.events.MouseButtonEvent")

---@class ui.DragStartEvent : ui.MouseButtonEvent
---@operator call: ui.DragStartEvent
local DragStartEvent = MouseButtonEvent + {}

function DragStartEvent:trigger()
	return self.current_target:onDragStart(self)
end

return DragStartEvent
