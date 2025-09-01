local UIEvent = require("ui.UIEvent")

---@class ui.MouseEvent : ui.UIEvent
---@operator call: ui.MouseEvent
---@field target ui.Node
---@field x number
---@field y number
---@field rx number Relative to target X with applied transforms
---@field ry number Relative to target Y with applied transforms
local MouseEvent = UIEvent + {}

MouseEvent.callback_name = "MouseEvent"

return MouseEvent
