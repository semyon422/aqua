local MouseButtonEvent = require("ui.input_events.MouseButtonEvent")

---@class ui.MouseClickEvent : ui.MouseButtonEvent
---@operator call: ui.MouseClickEvent
local MouseClickEvent = MouseButtonEvent + {}

return MouseClickEvent
