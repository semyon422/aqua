local UIEvent = require("ui.input.UIEvent")

---@class ui.FocusEvent : ui.UIEvent
---@operator call: ui.FocusEvent
---@field previously_focused ui.IInputHandler?
local FocusEvent = UIEvent + {}

function FocusEvent:trigger()
	return self.current_target:onFocus(self)
end

return FocusEvent
