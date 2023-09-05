local remote = {}

---@type function, function
local encode, decode

---@param coder table
function remote.set_coder(coder)
	encode, decode = coder.encode, coder.decode
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

---@param peer table
---@param id number?
---@param name string?
---@param ... any?
local function send(peer, id, name, ...)
	peer.epeer:send(encode({
		id = id,
		name = name,
		n = select("#", ...),
		...
	}))
end

---@param peer table
---@param name string
---@param ... any?
---@return any?...
local function run(peer, name, ...)
	if name:sub(1, 1) == "_" then
		send(peer, nil, name:sub(2), ...)
		return
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
	return function(...)
		return run(t, name, ...)
	end
end

---@param a table
---@param b table
---@return boolean
function peer_mt.__eq(a, b)
	return a.id == b.id
end

---@param epeer table|userdata
---@return table
function remote.peer(epeer)
	return setmetatable({
		epeer = epeer,
		id = tonumber(tostring(epeer):match("^.+:(%d+)$")),
	}, peer_mt)
end

---@param peer table
---@param e table
---@param handlers table
---@return any?...
local function _handle(peer, e, handlers)
	local handler = handlers[e.name]
	return handler and handler(peer, unpack(e, 1, e.n))
end

---@param peer table
---@param e table
---@param handlers table
local function handle(peer, e, handlers)
	if not e.id then
		_handle(peer, e, handlers)
		return
	end
	send(peer, e.id, nil, _handle(peer, e, handlers))
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

---@param data any
---@param epeer table|userdata
---@param handlers table
function remote.receive(data, epeer, handlers)
	local ok, e = pcall(decode, data)
	if not ok or type(e) ~= "table" then
		return
	end

	if e.name then
		handle(remote.peer(epeer), e, handlers)
	elseif e.id and tasks[e.id] then
		tasks[e.id](unpack(e, 1, e.n))
	end
end

return remote
