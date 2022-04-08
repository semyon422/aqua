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
		error(threadError .. "\n" .. self.event.trace)
	end

	local task = self.task

	local event = self.internalOutputChannel:pop()
	if event then
		if type(event) == "table" then
			if event[1] and task.result then
				local p = event
				task.result(p[2], p[3], p[4], p[5], p[6], p[7], p[8], p[9])
			elseif not event[1] and task.error then
				task.error(tostring(event[2]) .. "\n" .. (self.event.trace or ""))
			end
		end
		self.idle = true
	end

	local event = self.outputChannel:pop()
	while event do
		if task.receive then
			task.receive(event)
		end
		event = self.outputChannel:pop()
	end
	if not self.idle then
		self:updateLastTime()
	end
end

Thread.updateLastTime = function(self)
	self.lastTime = love.timer.getTime()
end

Thread.execute = function(self, task)
	self.idle = false
	self.task = task
	local f = task.f
	if type(f) == "function" then
		f = string.dump(f)
	end
	self.event = {
		name = "loadstring",
		trace = debug.traceback(),
		codestring = f,
		params = task.params,
	}
	self.internalInputChannel:push(self.event)
end

Thread.start = function(self)
	return self.thread:start()
end

Thread.stop = function(self)
	return self.internalInputChannel:push({
		name = "stop"
	})
end

Thread.receive = function(self, event)
	return self.inputChannel:push(event)
end

return Thread
