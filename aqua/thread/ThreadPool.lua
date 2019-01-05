local Thread = require("aqua.thread.Thread")

local ThreadPool = {}

ThreadPool.poolSize = 4
ThreadPool.keepAliveTime = 1

ThreadPool.threads = {}
ThreadPool.queue = {}

ThreadPool.execute = function(self, codestring, callback)
	self.queue[#self.queue + 1] = {codestring, callback}
	return self:update()
end

ThreadPool.update = function(self)
	for i = 1, self.poolSize do
		if self.threads[i] then
			self.threads[i]:update()
		end
	end
	local thread = self:getIdleThread()
	if thread and self.queue[1] then
		thread:execute(unpack(self.queue[1]))
		table.remove(self.queue, 1)
	end
end

ThreadPool.getIdleThread = function(self)
	local thread
	for i = 1, self.poolSize do
		thread = self.threads[i]
		if thread and thread:isIdle() then
			return thread
		end
	end
	
	for i = 1, self.poolSize do
		if not self.threads[i] then
			return self:createThread(i)
		end
	end
end

ThreadPool.createThread = function(self, threadId)
	local thread = Thread:new()
	thread.id = threadId
	thread:create(self.codestring:format(threadId))
	thread:start()
	self.threads[threadId] = thread
	return thread
end

ThreadPool.codestring = [[
	local aqua = require("aqua")
	
	local threadId = %d
	local inputChannel = love.thread.getChannel("input" .. threadId)
	local outputChannel = love.thread.getChannel("output" .. threadId)
	
	require("love.timer")
	startTime = love.timer.getTime()
	
	local event
	while true do
		event = inputChannel:demand()
		if event.action == "stop" then
			outputChannel:push({
				done = true
			})
			return
		elseif event.action == "loadstring" then
			local result = {pcall(loadstring(event.codestring))}
			outputChannel:push({
				result = result,
				done = true
			})
		end
	end
]]

return ThreadPool
