local KeyboardEvent = require("ui.input_events.KeyboardEvent")

---@class ui.KeyDownEvent : ui.KeyboardEvent
---@operator call: ui.KeyboardEvent
local KeyDownEvent = KeyboardEvent + {}

function KeyDownEvent:trigger()
	return self.current_target:onKeyDown(self)
end

return KeyDownEvent
