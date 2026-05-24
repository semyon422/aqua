local MouseEvent = require("ui.input.events.MouseEvent")

---@class ui.ScrollEvent : ui.MouseEvent
---@operator call: ui.ScrollEvent
---@field direction_x number
---@field direction_y number
local ScrollEvent = MouseEvent + {}

function ScrollEvent:trigger()
	return self:getDispatchTarget():onScroll(self)
end

return ScrollEvent
