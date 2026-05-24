local MouseButtonEvent = require("ui.input.events.MouseButtonEvent")

---@class ui.MouseClickEvent : ui.MouseButtonEvent
---@operator call: ui.MouseClickEvent
local MouseClickEvent = MouseButtonEvent + {}

function MouseClickEvent:trigger()
	return self:getDispatchTarget():onMouseClick(self)
end

return MouseClickEvent
