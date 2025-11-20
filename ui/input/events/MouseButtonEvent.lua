local MouseEvent = require("ui.input.events.MouseEvent")

---@class ui.MouseButtonEvent : ui.MouseEvent
---@operator call: ui.MouseButtonEvent
---@field button number
local MouseButtonEvent = MouseEvent + {}

return MouseButtonEvent
