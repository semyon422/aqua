local class = require("class")

---@class ui.UIEvent
---@operator call: ui.UIEvent
---@field callback_name string
---@field target ui.Node?
local UIEvent = class()

function UIEvent:new()
	self.stop = false
end

function UIEvent:stopPropagation()
	self.stop = true
end

return UIEvent
