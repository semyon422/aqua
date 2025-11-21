local KeyboardEvent = require("ui.input.events.KeyboardEvent")

---@class ui.TextInputEvent : ui.KeyboardEvent
---@operator call: ui.TextInputEvent
local TextInputEvent = KeyboardEvent + {}

function TextInputEvent:trigger()
	return self.current_target:onTextInput(self)
end

return TextInputEvent
