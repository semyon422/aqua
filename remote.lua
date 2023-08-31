local remote = {}

---@param data any|nil
---@return string
function remote.encode(data)
	error("mot implemented")
end

---@param data string
---@return any|nil
function remote.decode(data)
	error("mot implemented")
end

---@param f function
---@return function
function remote.wrap(f)
	return function(...)
		return coroutine.wrap(f)(...)
	end
end

local tasks = {}
local event_id = 0

remote.timeout = 10
local timeouts = {}

---@param peer userdata
---@param id number?
---@param name string?
---@param ... any?
---@return any?...
local function send(peer, id, name, ...)
	return peer:send(remote.encode({
		id = id,
		name = name,
		n = select("#", ...),
		...
	}))
end

---@param peer userdata
---@param name string
---@param ... any?
---@return any?...
local function run(peer, name, ...)
	if name:sub(1, 1) == "_" then
		return send(peer, nil, name:sub(2), ...)
	end

	local c = coroutine.running()
	if not c then
		error("attempt to yield from outside a coroutine")
	end

	event_id = event_id + 1
	local id = event_id

	send(peer, id, name, ...)

	local trace = debug.traceback(c)
	timeouts[id] = os.time() + remote.timeout
	tasks[id] = function(...)
		tasks[id] = nil
		timeouts[id] = nil
		local status, err = coroutine.resume(c, ...)
		if not status then
			error(err .. "\n" .. trace)
		end
	end

	return coroutine.yield()
end

local peer_mt = {}

---@param t table
---@param name string
---@return any
function peer_mt.__index(t, name)
	return rawget(t, name) or function(...)
		return run(t.peer, name, ...)
	end
end

---@param a table
---@param b table
---@return boolean
function peer_mt.__eq(a, b)
	return rawget(a, "id") == rawget(b, "id")
end

---@param peer userdata
---@return table
function remote.peer(peer)
	return setmetatable({
		peer = peer,
		id = tonumber(tostring(peer):match("^.+:(%d+)$")),
	}, peer_mt)
end

---@param peer userdata
---@param e table
---@param handlers table
---@return any?...
local function _handle(peer, e, handlers)
	local handler = handlers[e.name]
	return handler and handler(remote.peer(peer), unpack(e, 1, e.n))
end

---@param peer userdata
---@param e table
---@param handlers table
---@return any?...
local function handle(peer, e, handlers)
	if not e.id then
		return _handle(peer, e, handlers)
	end
	return send(peer, e.id, nil, _handle(peer, e, handlers))
end
handle = remote.wrap(handle)

function remote.update()
	local time = os.time()
	for id, t in pairs(timeouts) do
		if t <= time then
			tasks[id](nil, "timeout")
		end
	end
end

---@param event table
---@param handlers table
function remote.receive(event, handlers)
	local ok, e = pcall(remote.decode, event.data)
	if not ok or type(e) ~= "table" then
		return
	end

	if e.name then
		handle(event.peer, e, handlers)
	elseif e.id and tasks[e.id] then
		tasks[e.id](unpack(e, 1, e.n))
	end
end

return remote
