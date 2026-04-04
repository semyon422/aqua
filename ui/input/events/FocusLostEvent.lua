local UIEvent = require("ui.input.UIEvent")

---@class ui.FocusLostEvent : ui.UIEvent
---@operator call: ui.FocusLostEvent
---@field next_focused ui.View?
local FocusLostEvent = UIEvent + {}

function FocusLostEvent:trigger()
	return self:getDispatchTarget():onFocusLost(self)
end

return FocusLostEvent
