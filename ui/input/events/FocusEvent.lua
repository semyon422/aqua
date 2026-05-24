local UIEvent = require("ui.input.UIEvent")

---@class ui.FocusEvent : ui.UIEvent
---@operator call: ui.FocusEvent
---@field previously_focused ui.View?
local FocusEvent = UIEvent + {}

function FocusEvent:trigger()
	return self:getDispatchTarget():onFocus(self)
end

return FocusEvent
