local class = require("class")
local synctable = require("synctable")

local codestring

---@param id number
---@return string
local function getCodeString(id)
	if not codestring then
		local path = "aqua/thread/threadcode.lua"
		codestring = love.filesystem.read(path)
	end
	return (codestring:gsub('"<threadId>"', id))
end

---@class thread.Thread
---@operator call: thread.Thread
local Thread = class()

Thread.idle = true

---@param id number
function Thread:new(id)
	self.thread = love.thread.newThread(getCodeString(id))

	self.internalInputChannel = love.thread.getChannel("internalInput" .. id)
	self.internalOutputChannel = love.thread.getChannel("internalOutput" .. id)
	self.inputChannel = love.thread.getChannel("input" .. id)
	self.outputChannel = love.thread.getChannel("output" .. id)

	self.internalInputChannel:clear()
	self.internalOutputChannel:clear()
	self.inputChannel:clear()
	self.outputChannel:clear()

	self:updateLastTime()

	self.thread:start()
end

function Thread:update()
	local trace = self.task.trace

	local terr = self.thread:getError()
	if terr then
		error(terr .. "\n" .. trace)
	end

	local task = self.task

	local event = self.internalOutputChannel:pop()
	if event then
		self.idle = true
	end
	if type(event) == "table" then
		if event[1] then
			local ok, err = xpcall(
				task.result,
				debug.traceback,
				unpack(event, 2, event.n)
			)
			if not ok then
				error(err .. "\n" .. trace)
			end
		else
			error(tostring(event[2]) .. "\n" .. trace)
		end
	end

	local pool = self.pool
	pool.ignoreSyncThread = self
	event = self.outputChannel:pop()
	while event do
		synctable.set(pool.synctable, unpack(event))
		event = self.outputChannel:pop()
	end
	pool.ignoreSyncThread = nil
	if not self.idle then
		self:updateLastTime()
	end
end

function Thread:updateLastTime()
	self.lastTime = love.timer.getTime()
end

---@param task table
function Thread:execute(task)
	self.idle = false
	self.task = task
	self.internalInputChannel:push({
		name = "loadstring",
		codestring = task.f,
		trace = task.trace,
		args = task.args,
	})
end

---@return boolean
function Thread:isRunning()
	return self.thread:isRunning()
end

---@return number
function Thread:pushStop()
	return self.internalInputChannel:push({name = "stop"})
end

---@param event table
---@return number
function Thread:receive(event)
	return self.inputChannel:push(event)
end

return Thread
