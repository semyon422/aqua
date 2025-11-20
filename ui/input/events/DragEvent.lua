local MouseButtonEvent = require("ui.input.events.MouseButtonEvent")

---@class ui.DragEvent : ui.MouseButtonEvent
---@operator call: ui.DragEvent
local DragEvent = MouseButtonEvent + {}

function DragEvent:trigger()
	return self.current_target:onDrag(self)
end

return DragEvent
