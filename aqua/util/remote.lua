local remote = {}

function remote.encode(data)
	error("mot implemented")
end

function remote.decode(data)
	error("mot implemented")
end

function remote.wrap(f)
	return function(...)
		return coroutine.wrap(f)(...)
	end
end

local tasks = {}
local event_id = 0

remote.timeout = 10
local timeouts = {}

local function _unpack(t, i, j)
	if not t then return end
	if i == j then return t[i] end
	return t[i], _unpack(t, i + 1, j)
end

local function send(peer, id, name, ...)
	return peer:send(remote.encode({
		id = id,
		name = name,
		...
	}))
end

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

local peer_mt = {
	__index = function(t, name)
		return rawget(t, name) or function(...)
			return run(t.peer, name, ...)
		end
	end,
	__eq = function(a, b)
		return rawget(a, "id") == rawget(b, "id")
	end,
}
function remote.peer(peer)
	return setmetatable({
		peer = peer,
		id = tonumber(tostring(peer):match("^.+:(%d+)$")),
	}, peer_mt)
end

local function no_handler(...) end
local handle = remote.wrap(function(peer, e, handlers)
	local handler = handlers[e.name] or no_handler
	return send(peer, e.id, nil, handler(remote.peer(peer), _unpack(e, 1, 8)))
end)

function remote.update()
	local time = os.time()
	for id, t in pairs(timeouts) do
		if t <= time then
			tasks[id](nil, "timeout")
		end
	end
end

function remote.receive(event, handlers)
	local e = remote.decode(event.data)

	if e.name then
		return handle(event.peer, e, handlers)
	end

	if e.id and tasks[e.id] then
		return tasks[e.id](_unpack(e, 1, 8))
	end
end

return remote
