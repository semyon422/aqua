local Class = require("aqua.util.Class")

local Thread = Class:new()

Thread.id = 0
Thread.idle = true

Thread.create = function(self, codestring)
	self.thread = love.thread.newThread(codestring)
	self.inputChannel = love.thread.getChannel("input" .. self.id)
	self.outputChannel = love.thread.getChannel("output" .. self.id)
	self.inputChannel:clear()
	self.outputChannel:clear()
	
	self:updateLastTime()
end

Thread.update = function(self)
	local threadError = self.thread:getError()
	if threadError then
		self.pool:send({
			name = "threadError",
			error = threadError .. "\n" .. self.currentEvent.trace
		})
		error(threadError)
	end
	
	local event = self:receive()
	while event do
		if event.result and not event.result[1] then
			self.pool:send({
				name = "threadError",
				error = event.result[2]
			})
		end
		
		self.callback(event.result)
		if event.done then
			self.idle = true
		end
		event = self:receive()
		self:updateLastTime()
	end
end

Thread.updateLastTime = function(self)
	self.lastTime = love.timer.getTime()
end

Thread.isIdle = function(self)
	return self.idle
end

Thread.execute = function(self, codestring, args, callback)
	self.callback = callback
	self.idle = false
	self.currentEvent = {
		action = "loadstring",
		codestring = codestring,
		args = args,
		trace = debug.traceback()
	}
	self:send(self.currentEvent)
end

Thread.start = function(self)
	return self.thread:start()
end

Thread.send = function(self, event)
	return self.inputChannel:push(event)
end

Thread.receive = function(self)
	return self.outputChannel:pop()
end

Thread.isRunning = function(self)
	return self.thread:isRunning()
end

return Thread
