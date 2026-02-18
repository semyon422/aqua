local UIEvent = require("ui.input.UIEvent")

---@class ui.FocusLostEvent : ui.UIEvent
---@operator call: ui.FocusLostEvent
---@field next_focused ui.Node?
local FocusLostEvent = UIEvent + {}

function FocusLostEvent:trigger()
	return self.current_target:onFocusLost(self)
end

return FocusLostEvent
