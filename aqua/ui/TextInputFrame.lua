local Button = require("aqua.ui.Button")
local TextInput = require("aqua.util.TextInput")

local TextInputFrame = Button:new()

TextInputFrame.construct = function(self)
	Button.construct(self)
	
	self.textInput = TextInput:new()
end

TextInputFrame.receive = function(self, event)
	if event.name == "resize" then
		self:reload()
	end
	
	self.textInput:receive(event)
	self:setText(self.textInput.text)
end

return TextInputFrame
