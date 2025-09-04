local KeyboardEvent = require("ui.input_events.KeyboardEvent")

---@class ui.KeyUpEvent : ui.KeyboardEvent
---@operator call: ui.KeyboardEvent
local KeyUpEvent = KeyboardEvent + {}

function KeyUpEvent:trigger()
	self.current_target:onKeyUp(self)
end

return KeyUpEvent
