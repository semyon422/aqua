local Class = require("aqua.util.Class")
local utf8 = require("utf8")

local TextInput = Class:new()

TextInput.construct = function(self)
	self.text = self.text or ""
	self.offset = utf8.len(self.text)
end

TextInput.split = function(self, text, utf8offset)
	local offset = utf8.offset(text, utf8offset + 1) or 1
	return text:sub(1, offset - 1), text:sub(offset)
end

TextInput.reset = function(self)
	self.text = ""
	self.offset = 0
end

TextInput.receive = function(self, event)
	if event.name == "textinput" then
		local char = event.args[1]
		
		local left, right = self:split(self.text, self.offset)
		self.text = left .. char .. right
		self.offset = self.offset + utf8.len(char)
	elseif event.name == "keypressed" then
		local key = event.args[1]
		if key == "backspace" then
			self:removeChar(-1)
		elseif key == "delete" then
			self:removeChar(1)
		elseif key == "left" then
			self.offset = math.max(0, self.offset - 1)
		elseif key == "right" then
			self.offset = math.min(utf8.len(self.text), self.offset + 1)
		elseif key == "end" then
			self.offset = utf8.len(self.text)
		elseif key == "home" then
			self.offset = 0
		end
	end
end

TextInput.removeChar = function(self, direction)
	local _
	local left, right = self:split(self.text, self.offset)
	
	if direction == -1 then
		left, _ = self:split(left, utf8.len(left) - 1)
		self.offset = math.max(0, self.offset - 1)
	else
		_, right = self:split(right, 1)
	end
	
	self.text = left .. right
end

return TextInput
