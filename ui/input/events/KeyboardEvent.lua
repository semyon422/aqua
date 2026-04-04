local UIEvent = require("ui.input.UIEvent")

---@class ui.KeyboardEvent : ui.UIEvent
---@operator call: ui.KeyboardEvent
---@field key love.KeyConstant
local KeyboardEvent = UIEvent + {}

return KeyboardEvent
