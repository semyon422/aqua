local MouseButtonEvent = require("ui.input_events.MouseButtonEvent")

---@class ui.DragEvent : ui.MouseButtonEvent
---@operator call: ui.DragEvent
local DragEvent = MouseButtonEvent + {}

DragEvent.callback_name = "onDrag"

return DragEvent
