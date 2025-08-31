local MouseButtonEvent = require("ui.input_events.MouseButtonEvent")

---@class ui.DragEndEvent : ui.MouseButtonEvent
---@operator call: ui.DragEndEvent
local DragEndEvent = MouseButtonEvent + {}

DragEndEvent.callback_name = "onDragEnd"

return DragEndEvent
