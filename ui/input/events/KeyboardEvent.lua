local UIEvent = require("ui.input.UIEvent")

---@class ui.KeyboardEvent : ui.UIEvent
---@operator call: ui.KeyboardEvent
---@field key string
local KeyboardEvent = UIEvent + {}

return KeyboardEvent
