-- Symmetric coroutines
-- https://www.inf.puc-rio.br/~roberto/docs/corosblp.pdf

local coro = {}

local ended = {}
---@type thread?
local current

---@param f function
---@return thread
function coro.create(f)
	return coroutine.create(function(...)
		return ended, f(...)
	end)
end

---@param co thread?
---@param ... any
---@return any ...
local function dispatch(co, ...)
	assert(co ~= ended, "coroutine ended without transfering control")
	current = co
	if not co then
		return ...
	end
	return dispatch(select(2, assert(coroutine.resume(co, ...))))
end

---@param co thread?
---@param ... any
---@return any ...
function coro.transfer(co, ...)
	if current then
		return coroutine.yield(co, ...)
	end
	return dispatch(co, ...)
end

-- tests

local function test_concat(c, ...)
	return select(1, ...) .. c, select(2, ...)
end

---@type thread, thread
local co1, co2

local co1_ended = false
co1 = coro.create(function(...)
	coro.transfer(nil, test_concat("e", coro.transfer(co2, test_concat("q", ...))))
	co1_ended = true
end)

local co2_ended = false
co2 = coro.create(function(...)
	coro.transfer(co1, test_concat("w", ...))
	co2_ended = true
end)

assert(not co1_ended)
assert(not co2_ended)

local function assert_values(...)
	assert(select("#", ...) == 4)
	assert(select(1, ...) == "qwe")
	assert(select(2, ...) == nil)
	assert(select(3, ...) == 2)
	assert(select(4, ...) == nil)
end

assert_values(coro.transfer(co1, "", nil, 2, nil))

return coro
