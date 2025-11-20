local KeyboardEvent = require("ui.input.events.KeyboardEvent")

---@class ui.KeyUpEvent : ui.KeyboardEvent
---@operator call: ui.KeyboardEvent
local KeyUpEvent = KeyboardEvent + {}

function KeyUpEvent:trigger()
	return self.current_target:onKeyUp(self)
end

return KeyUpEvent
