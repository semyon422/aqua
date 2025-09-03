local MouseEvent = require("ui.input_events.MouseEvent")

---@class ui.ScrollEvent : ui.MouseEvent
---@operator call: ui.ScrollEvent
---@field direction_x number
---@field direction_y number
local ScrollEvent = MouseEvent + {}

function ScrollEvent:trigger()
	self.current_target:onScroll(self)
end

return ScrollEvent
