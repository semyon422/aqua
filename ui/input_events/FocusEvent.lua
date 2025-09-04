local UIEvent = require("ui.UIEvent")

---@class ui.FocusEvent : ui.UIEvent
---@operator call: ui.FocusEvent
---@field previously_focused ui.Node?
local FocusEvent = UIEvent + {}

function FocusEvent:trigger()
	self.current_target:onFocus(self)
end

return FocusEvent
