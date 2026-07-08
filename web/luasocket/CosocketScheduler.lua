local socket = require("socket")
local class = require("class")
local table_util = require("table_util")

---@alias web.CosocketWaitMode "read"|"write"

---@class web.CosocketTimer
---@field time number
---@field co thread
---@field active boolean
---@field resume_args {n: integer, [integer]: any}

---@class web.CosocketWaiter
---@field soc any
---@field mode web.CosocketWaitMode?
---@field timer web.CosocketTimer?

---@class web.CosocketScheduler
---@operator call: web.CosocketScheduler
---@field select fun(recvt: any[], sendt: any[], timeout: number?): any[]?, any[]?, string?
---@field get_time fun(): number
---@field read_waiters {[any]: thread[]}
---@field write_waiters {[any]: thread[]}
---@field waiters {[thread]: web.CosocketWaiter}
---@field timers web.CosocketTimer[]
local CosocketScheduler = class()

---@param select_func (fun(recvt: any[], sendt: any[], timeout: number?): any[]?, any[]?, string?)?
---@param get_time (fun(): number)?
function CosocketScheduler:new(select_func, get_time)
	self.select = select_func or socket.select
	self.get_time = get_time or socket.gettime
	self.read_waiters = {}
	self.write_waiters = {}
	self.waiters = {}
	self.timers = {}
end

---@param mode web.CosocketWaitMode
---@return {[any]: thread[]}
function CosocketScheduler:getWaiters(mode)
	if mode == "read" then
		return self.read_waiters
	elseif mode == "write" then
		return self.write_waiters
	end
	error("invalid wait mode: " .. tostring(mode))
end

---@param queue thread[]
---@param co thread
local function remove_from_queue(queue, co)
	local index = table_util.indexof(queue, co)
	if index then
		table.remove(queue, index)
	end
end

---@param co thread
---@return web.CosocketWaiter?
function CosocketScheduler:removeWaiter(co)
	local waiter = self.waiters[co]
	if not waiter then
		return
	end

	self.waiters[co] = nil

	local timer = waiter.timer
	if timer then
		timer.active = false
	end

	local mode = waiter.mode
	if mode then
		local waiters = self:getWaiters(mode)
		local queue = waiters[waiter.soc]
		if queue then
			remove_from_queue(queue, co)
			if not queue[1] then
				waiters[waiter.soc] = nil
			end
		end
	end

	return waiter
end

---@param co thread
---@param ... any
function CosocketScheduler:resume(co, ...)
	self:removeWaiter(co)
	if coroutine.status(co) == "dead" then
		return
	end
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		error(err, 0)
	end
end

---@param co thread
---@param duration number
---@param resume_args {n: integer, [integer]: any}
---@return web.CosocketTimer
function CosocketScheduler:addTimer(co, duration, resume_args)
	local timer = {
		time = self.get_time() + duration,
		co = co,
		active = true,
		resume_args = resume_args,
	}
	table.insert(self.timers, timer)
	return timer
end

---@param mode web.CosocketWaitMode
---@param soc any
---@param timeout number?
---@return true?
---@return string?
function CosocketScheduler:wait(mode, soc, timeout)
	local co = coroutine.running()
	if not co then
		error("attempt to yield from outside a coroutine")
	end

	local waiters = self:getWaiters(mode)
	local queue = waiters[soc]
	if not queue then
		queue = {}
		waiters[soc] = queue
	end
	table.insert(queue, co)

	---@type web.CosocketWaiter
	local waiter = {
		soc = soc,
		mode = mode,
	}
	self.waiters[co] = waiter

	if timeout then
		waiter.timer = self:addTimer(co, timeout, table_util.pack(nil, "timeout"))
	end

	return coroutine.yield()
end

---@param soc any
---@param timeout number?
---@return true?
---@return string?
function CosocketScheduler:waitRead(soc, timeout)
	return self:wait("read", soc, timeout)
end

---@param soc any
---@param timeout number?
---@return true?
---@return string?
function CosocketScheduler:waitWrite(soc, timeout)
	return self:wait("write", soc, timeout)
end

---@param duration number
---@return true?
---@return string?
function CosocketScheduler:sleep(duration)
	local co = coroutine.running()
	if not co then
		error("attempt to yield from outside a coroutine")
	end

	self.waiters[co] = {
		soc = false,
		timer = self:addTimer(co, duration, table_util.pack(true)),
	}

	return coroutine.yield()
end

---@param co thread
---@param err string?
function CosocketScheduler:cancel(co, err)
	self:resume(co, nil, err or "canceled")
end

---@param soc any
---@param err string?
function CosocketScheduler:closeSocket(soc, err)
	err = err or "closed"
	for _, mode in ipairs({"read", "write"}) do
		local waiters = self:getWaiters(mode)
		local queue = waiters[soc]
		waiters[soc] = nil
		if queue then
			for _, co in ipairs(queue) do
				self:resume(co, nil, err)
			end
		end
	end
end

---@return number?
function CosocketScheduler:getNextTimerDelay()
	local now = self.get_time()
	local delay
	for _, timer in ipairs(self.timers) do
		if timer.active then
			local timer_delay = math.max(timer.time - now, 0)
			if not delay or timer_delay < delay then
				delay = timer_delay
			end
		end
	end
	return delay
end

---@return boolean resumed
function CosocketScheduler:updateTimers()
	local now = self.get_time()
	local resumed = false
	for _, timer in ipairs(self.timers) do
		if timer.active and timer.time <= now then
			timer.active = false
			self:resume(timer.co, table_util.unpack(timer.resume_args))
			resumed = true
		end
	end
	return resumed
end

---@param waiters {[any]: thread[]}
---@return any[]
local function get_sockets(waiters)
	local sockets = {}
	for soc in pairs(waiters) do
		table.insert(sockets, soc)
	end
	return sockets
end

---@param waiters {[any]: thread[]}
---@param soc any
---@return thread?
local function pop_waiter(waiters, soc)
	local queue = waiters[soc]
	if not queue then
		return
	end

	local co = table.remove(queue, 1)
	if not queue[1] then
		waiters[soc] = nil
	end
	return co
end

---@param timeout number?
---@return boolean?
---@return string?
function CosocketScheduler:update(timeout)
	local resumed = self:updateTimers()

	local read_sockets = get_sockets(self.read_waiters)
	local write_sockets = get_sockets(self.write_waiters)
	if not read_sockets[1] and not write_sockets[1] then
		return resumed
	end

	local timer_delay = self:getNextTimerDelay()
	local select_timeout = timeout or 0
	if timer_delay and timer_delay < select_timeout then
		select_timeout = timer_delay
	end

	local ready_read, ready_write, err = self.select(read_sockets, write_sockets, select_timeout)
	if err and err ~= "timeout" then
		return nil, err
	end

	for _, soc in ipairs(ready_read or {}) do
		local co = pop_waiter(self.read_waiters, soc)
		if co then
			self:resume(co, true)
			resumed = true
		end
	end

	for _, soc in ipairs(ready_write or {}) do
		local co = pop_waiter(self.write_waiters, soc)
		if co then
			self:resume(co, true)
			resumed = true
		end
	end

	return self:updateTimers() or resumed
end

return CosocketScheduler
