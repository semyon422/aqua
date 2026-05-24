local UIEvent = require("ui.input.UIEvent")

---@class ui.KeyboardEvent : ui.UIEvent
---@operator call: ui.KeyboardEvent
---@field key love.KeyConstant
---@field is_repeated boolean
local KeyboardEvent = UIEvent + {}

return KeyboardEvent
