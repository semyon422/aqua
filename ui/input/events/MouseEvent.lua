local UIEvent = require("ui.input.UIEvent")

---@class ui.MouseEvent : ui.UIEvent
---@operator call: ui.MouseEvent
---@field button number
---@field x number
---@field y number
local MouseEvent = UIEvent + {}

return MouseEvent
