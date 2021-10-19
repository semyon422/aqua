local Class = require("aqua.util.Class")

local Thread = Class:new()

Thread.id = 0
Thread.idle = true

Thread.create = function(self, codestring)
	self.thread = love.thread.newThread(codestring)

	self.internalInputChannel = love.thread.getChannel("internalInput" .. self.id)
	self.internalOutputChannel = love.thread.getChannel("internalOutput" .. self.id)
	self.inputChannel = love.thread.getChannel("input" .. self.id)
	self.outputChannel = love.thread.getChannel("output" .. self.id)

	self.internalInputChannel:clear()
	self.internalOutputChannel:clear()
	self.inputChannel:clear()
	self.outputChannel:clear()

	self:updateLastTime()
end

Thread.update = function(self)
	local threadError = self.thread:getError()
	if threadError then
		local errorMessage = threadError .. "\n" .. self.currentEvent.trace
		self.pool:send({
			name = "ThreadError",
			error = errorMessage
		})
		print(errorMessage)
	end

	local event = self.internalOutputChannel:pop()
	while event do
		if event.result and not event.result[1] then
			local errorMessage = event.result[2]
			self.pool:send({
				name = "ThreadError",
				error = errorMessage
			})
			print(errorMessage)
		end

		self.pool:send(event)
		if event.done then
			self.idle = true
		end
		event = self.internalOutputChannel:pop()
		self:updateLastTime()
	end

	local event = self.outputChannel:pop()
	while event do
		self.pool:send(event)
		event = self.outputChannel:pop()
		self:updateLastTime()
	end
end

Thread.updateLastTime = function(self)
	self.lastTime = love.timer.getTime()
end

Thread.isIdle = function(self)
	return self.idle
end

Thread.execute = function(self, task)
	local codestring = string.dump(task[1])
	local args = task[2]
	self.idle = false
	self.currentEvent = {
		action = "loadstring",
		codestring = codestring,
		args = args,
		trace = debug.traceback()
	}
	self.internalInputChannel:push(self.currentEvent)
end

Thread.start = function(self)
	return self.thread:start()
end

Thread.receiveInternal = function(self, event)
	return self.internalInputChannel:push(event)
end

Thread.receive = function(self, event)
	return self.inputChannel:push(event)
end

Thread.isRunning = function(self)
	return self.thread:isRunning()
end

return Thread
