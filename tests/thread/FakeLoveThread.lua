local class = require("class")

---@class thread.FakeLoveThread
---@operator call: thread.FakeLoveThread
local FakeLoveThread = class()

---@param id number
function FakeLoveThread:new(id)
	self.id = id
	self.inputChannel = {}
	self.outputChannel = {}
end

function FakeLoveThread:start()
	self.running = true
end

---@return boolean
function FakeLoveThread:isRunning()
	return self.running
end

---@return string?
function FakeLoveThread:getError()
	return self.error
end

---@param event any
function FakeLoveThread:push(event)
	table.insert(self.inputChannel, event)
end

---@return any
function FakeLoveThread:pop()
	return table.remove(self.outputChannel)
end

---@param event any
function FakeLoveThread:pushOutput(event)
	table.insert(self.outputChannel, event)
end

return FakeLoveThread
