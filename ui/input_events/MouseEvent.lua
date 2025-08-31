local UIEvent = require("ui.UIEvent")

---@class ui.MouseEvent : ui.UIEvent
---@operator call: ui.MouseEvent
---@field target ui.Node
---@field x number
---@field y number
local MouseEvent = UIEvent + {}

MouseEvent.callback_name = "MouseEvent"

return MouseEvent
