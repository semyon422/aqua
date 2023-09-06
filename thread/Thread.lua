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
---@param st table
function Thread:new(id, st)
	self.id = id
	self.synctable = st

	self.thread = love.thread.newThread(getCodeString(id))

	self.inputChannel = love.thread.getChannel("input" .. id)
	self.outputChannel = love.thread.getChannel("output" .. id)

	self.inputChannel:clear()
	self.outputChannel:clear()

	self:updateLastTime()

	self.thread:start()

	self.lockSync = false
end

function Thread:update()
	local trace = self.task.trace

	local terr = self.thread:getError()
	if terr then
		error(terr .. "\n" .. trace)
	end

	local task = self.task

	local event = self.outputChannel:pop()
	while event do
		if event.name == "result" then
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
			self.idle = true
		elseif event.name == "synctable" then
			self.lockSync = true
			synctable.set(self.synctable, unpack(event, 1, event.n))
			self.lockSync = false
		end
		event = self.outputChannel:pop()
	end

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
	self.inputChannel:push({
		name = "loadstring",
		codestring = task.f,
		args = task.args,
	})
end

---@return boolean
function Thread:isRunning()
	return self.thread:isRunning()
end

---@return number
function Thread:pushStop()
	return self.inputChannel:push({name = "stop"})
end

---@param event table
function Thread:receive(event)
	self.inputChannel:push(event)
end

---@param ... any?
function Thread:sync(...)
	if self.lockSync then
		return
	end
	self.inputChannel:push({
		name = "synctable",
		n = select("#", ...),
		...
	})
end

return Thread
