local class = require("class")
local synctable = require("synctable")
local LoveThread = require("thread.LoveThread")

---@class thread.IWorkerThread
---@field getError fun(self: thread.IWorkerThread): string?
---@field pop fun(self: thread.IWorkerThread): thread.Event?
---@field push fun(self: thread.IWorkerThread, event: thread.Event)
---@field isRunning fun(self: thread.IWorkerThread): boolean
---@field start fun(self: thread.IWorkerThread)

---@class thread.Event: {n: integer?}
---@field name "result"|"synctable"|"loadstring"|"init"|"stop"
---@field codestring function|string?
---@field args table?
---@field [integer] any

---@class thread.Thread
---@operator call: thread.Thread
---@field id integer
---@field synctable table
---@field thread thread.IWorkerThread
---@field task thread.Task
local Thread = class()

Thread.idle = true
Thread.lockSync = false
Thread.lastTime = 0

---@param id integer
---@param synct table
---@param love_thread thread.IWorkerThread?
function Thread:new(id, synct, love_thread)
	self.id = id
	self.synctable = synct
	self.thread = love_thread or LoveThread(id)
end

function Thread:update()
	local trace = self.task.trace

	local terr = self.thread:getError()
	if terr then
		error(terr .. "\n" .. trace)
	end

	local task = self.task

	local event = self.thread:pop()
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
		event = self.thread:pop()
	end
end

---@param time number
function Thread:updateLastTime(time)
	self.lastTime = time
end

---@param task thread.Task
function Thread:execute(task)
	self.idle = false
	self.task = task
	self.thread:push({
		name = "loadstring",
		codestring = task.f,
		args = task.args,
	})
end

---@return boolean
function Thread:isRunning()
	return self.thread:isRunning()
end

function Thread:start()
	self.thread:start()
end

---@param init_func string?
---@param args table?
function Thread:init(init_func, args)
	self.thread:push({
		name = "init",
		codestring = init_func,
		args = args or {},
	})
end

function Thread:pushStop()
	self.thread:push({name = "stop"})
end

---@param ... any?
function Thread:sync(...)
	if self.lockSync then
		return
	end
	self.thread:push({
		name = "synctable",
		n = select("#", ...),
		...,
	})
end

return Thread
