local UIEvent = require("ui.input.UIEvent")

---@class ui.HoverEvent : ui.UIEvent
---@operator call: ui.HoverEvent
local HoverEvent = UIEvent + {}

function HoverEvent:trigger()
	return self.current_target:onHover(self)
end

return HoverEvent
