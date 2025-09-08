local class = require("class")
local table_util = require("table_util")

---@class im.MouseInput
---@operator call: im.MouseInput
local MouseInput = class()

function MouseInput:new()
	---@type {[integer]: true}, {[integer]: true}, {[integer]: true}
	self.down, self.pressed, self.released = {}, {}, {}
	self.captured = false
end

function MouseInput:step()
	table_util.clear(self.pressed)
	table_util.clear(self.released)

	self.scroll_delta = 0
end

---@param captured any?
function MouseInput:capture(captured)
	self.captured = not not captured
end

---@param button integer
---@return boolean
function MouseInput:mousepressed(button)
	self.down[button] = true
	self.pressed[button] = true
	return self.captured
end

---@param button integer
---@return boolean
function MouseInput:mousereleased(button)
	self.down[button] = nil
	self.released[button] = true

	return self.captured
end

---@return boolean
function MouseInput:mousemoved()
	return self.captured
end

---@param scroll_delta number
---@return boolean
function MouseInput:wheelmoved(scroll_delta)
	self.scroll_delta = scroll_delta

	return self.captured
end

return MouseInput
