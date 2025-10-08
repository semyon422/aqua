local UIEvent = require("ui.UIEvent")

---@class ui.MouseEvent : ui.UIEvent
---@operator call: ui.MouseEvent
---@field target ui.Node
---@field button number
---@field x number
---@field y number
local MouseEvent = UIEvent + {}

return MouseEvent
