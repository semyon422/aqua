local MouseEvent = require("ui.input_events.MouseEvent")

---@class ui.ScrollEvent : ui.MouseEvent
---@operator call: ui.ScrollEvent
---@field direction_x number
---@field direction_y number
local ScrollEvent = MouseEvent + {}

ScrollEvent.callback_name = "onScroll"

return ScrollEvent
