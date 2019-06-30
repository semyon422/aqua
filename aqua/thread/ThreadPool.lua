local Thread = require("aqua.thread.Thread")
local Class = require("aqua.util.Class")

local ThreadPool = {}

ThreadPool.poolSize = 4
ThreadPool.keepAliveTime = 1

ThreadPool.threads = {}
ThreadPool.queue = {}

ThreadPool.execute = function(self, codestring, args, callback)
	self.queue[#self.queue + 1] = {codestring, args, callback}
	return self:update()
end

ThreadPool.update = function(self)
	local currentTime = love.timer.getTime()
	
	for i = 1, self.poolSize do
		local thread = self.threads[i]
		if thread then
			thread:update()
			if thread.idle and currentTime - thread.lastTime > self.keepAliveTime then
				thread.callback = self.threadStopCallback
				thread:send({
					action = "stop"
				})
				self.threads[i] = nil
			end
		end
	end
	
	if self.queue[1] then
		local thread = self:getIdleThread()
		if thread then
			thread:execute(unpack(self.queue[1]))
			table.remove(self.queue, 1)
		end
	end
end

ThreadPool.threadStopCallback = function(thread) end

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
	thread:create(self.codestring:format(("%q"):format(package.path), threadId))
	thread:start()
	self.threads[threadId] = thread
	return thread
end

ThreadPool.codestring = [[
	package.path = %s
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
			local result = {pcall(loadstring(event.codestring), unpack(event.args))}
			if not result[1] then
				print(unpack(result))
			end
			outputChannel:push({
				result = result,
				done = true
			})
		end
	end
]]

return ThreadPool
