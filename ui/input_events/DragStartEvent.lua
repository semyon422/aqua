local MouseButtonEvent = require("ui.input_events.MouseButtonEvent")

---@class ui.DragStartEvent : ui.MouseButtonEvent
---@operator call: ui.DragStartEvent
local DragStartEvent = MouseButtonEvent + {}

return DragStartEvent
