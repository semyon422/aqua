local Thread = {}

Thread.id = 0
Thread.idle = true

Thread.new = function(self)
	local thread = {}
	
	setmetatable(thread, self)
	self.__index = self
	
	return thread
end

Thread.create = function(self, codestring)
	self.thread = love.thread.newThread(codestring)
	self.inputChannel = love.thread.getChannel("input" .. self.id)
	self.outputChannel = love.thread.getChannel("output" .. self.id)
end

Thread.update = function(self)
	local threadError = self.thread:getError()
	if threadError then
		error(threadError)
	end
	
	local event = self:receive()
	while event do
		self.callback(event.result)
		if event.done then
			self.idle = true
		end
		event = self:receive()
	end
end

Thread.isIdle = function(self)
	return self.idle
end

Thread.execute = function(self, codestring, callback)
	self.callback = callback
	self.idle = false
	self:send({
		action = "loadstring",
		codestring = codestring
	})
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