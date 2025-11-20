local UIEvent = require("ui.input.UIEvent")

---@class ui.FocusLostEvent : ui.UIEvent
---@operator call: ui.FocusLostEvent
---@field next_focused ui.IInputHandler?
local FocusLostEvent = UIEvent + {}

function FocusLostEvent:trigger()
	return self.current_target:onFocus(self)
end

return FocusLostEvent
