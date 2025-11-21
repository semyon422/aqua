local UIEvent = require("ui.input.UIEvent")

---@class ui.HoverLostEvent : ui.UIEvent
---@operator call: ui.HoverLostEvent
local HoverLostEvent = UIEvent + {}

function HoverLostEvent:trigger()
	return self.current_target:onHoverLost(self)
end

return HoverLostEvent
