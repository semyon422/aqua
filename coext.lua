local resume = coroutine.resume
local yield = coroutine.yield
local create = coroutine.create
local running = coroutine.running

local coext = {}

function coext.export()
	coroutine.resume = coext.resume
	coroutine.yield = coext.yield
	coroutine.create = coext.create
	coroutine.wrap = coext.wrap
	coroutine.newyield = coext.newyield
	coroutine.yieldto = coext.yieldto
end

---@alias coroext.AsyncFunc async fun(...: any): ...: any

---@param co thread
---@param ok boolean
---@param ... any
---@return boolean ok
---@return any ...
local function resume_next(co, ok, ...)
	if not ok then
		return ok, ... -- errored
	elseif co == ... then
		return ok, select(2, ...) -- ended
	end
	return resume_next(co, resume(co, yield(...)))
end

---@param f coroext.AsyncFunc
---@return thread
---@nodiscard
function coext.create(f)
	return create(function(...)
		return running(), f(...)
	end)
end

---@param co thread
---@param ... any
---@return boolean ok
---@return any ...
function coext.resume(co, ...)
	return resume_next(co, resume(co, ...))
end

---@async
---@param ... any
---@return any ...
function coext.yield(...)
	return yield(running(), ...)
end

---@param co thread?
---@param ... any
---@return coroext.AsyncFunc
function coext.yieldto(co, ...)
	return yield(co, ...)
end

---@param co thread?
---@return coroext.AsyncFunc
function coext.newyield(co)
	co = co or running()
	return function(...)
		return yield(co, ...)
	end
end

---@param ok boolean
---@param ... any
---@return any
local function assert_skip(ok, ...)
	if not ok then
		error(..., 0)
	end
	return ...
end

---@param f coroext.AsyncFunc
---@return fun(...: any): ...: any
---@nodiscard
function coext.wrap(f)
	local co = coext.create(f)
	return function(...)
		return assert_skip(coext.resume(co, ...))
	end
end

return coext
