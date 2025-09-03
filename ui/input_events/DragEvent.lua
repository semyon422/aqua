local MouseButtonEvent = require("ui.input_events.MouseButtonEvent")

---@class ui.DragEvent : ui.MouseButtonEvent
---@operator call: ui.DragEvent
local DragEvent = MouseButtonEvent + {}

return DragEvent
