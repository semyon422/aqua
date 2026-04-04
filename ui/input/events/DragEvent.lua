local MouseButtonEvent = require("ui.input.events.MouseButtonEvent")

---@class ui.DragEvent : ui.MouseButtonEvent
---@operator call: ui.DragEvent
local DragEvent = MouseButtonEvent + {}

function DragEvent:trigger()
	return self:getDispatchTarget():onDrag(self)
end

return DragEvent
