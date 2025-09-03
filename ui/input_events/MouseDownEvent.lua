local MouseButtonEvent = require("ui.input_events.MouseButtonEvent")

---@class ui.MouseDownEvent : ui.MouseButtonEvent
---@operator call: ui.MouseDownEvent
local MouseDownEvent = MouseButtonEvent + {}

return MouseDownEvent
