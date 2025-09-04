local KeyboardEvent = require("ui.input_events.KeyboardEvent")

---@class ui.TextInputEvent : ui.KeyboardEvent
---@operator call: ui.TextInputEvent
local TextInputEvent = KeyboardEvent + {}

function TextInputEvent:trigger()
	self.current_target:onTextInput(self)
end

return TextInputEvent
