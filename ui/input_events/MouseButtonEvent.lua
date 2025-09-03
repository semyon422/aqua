local MouseEvent = require("ui.input_events.MouseEvent")

---@class ui.MouseButtonEvent : ui.MouseEvent
---@operator call: ui.MouseButtonEvent
---@field button number
local MouseButtonEvent = MouseEvent + {}

return MouseButtonEvent
