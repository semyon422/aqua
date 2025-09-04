local UIEvent = require("ui.UIEvent")

---@class ui.FocusLostEvent : ui.UIEvent
---@operator call: ui.FocusLostEvent
---@field next_focused ui.Node?
local FocusLostEvent = UIEvent + {}

function FocusLostEvent:trigger()
	self.current_target:onFocus(self)
end

return FocusLostEvent
