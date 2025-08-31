local MouseButtonEvent = require("ui.input_events.MouseButtonEvent")

---@class ui.MouseUpEvent : ui.MouseButtonEvent
---@operator call: ui.MouseUpEvent
local MouseUpEvent = MouseButtonEvent + {}

MouseUpEvent.callback_name = "onMouseUp"

return MouseUpEvent
