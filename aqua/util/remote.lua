local MessagePack = require("MessagePack")

local remote = {}

function remote.wrap(f)
	return function(...)
		return coroutine.wrap(f)(...)
	end
end

local tasks = {}
local event_id = 0

local timeout = 10
local timeouts = {}

local function _unpack(t, i, j)
	if not t then return end
	if i == j then return t[i] end
	return t[i], _unpack(t, i + 1, j)
end

local send = function(peer, id, name, ...)
	return peer:send(MessagePack.pack({
		id = id,
		name = name,
		...
	}))
end

local run = function(peer, name, ...)
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
	timeouts[id] = os.time() + timeout
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
remote.peer = function(peer)
	return setmetatable({
		peer = peer,
		id = tonumber(tostring(peer):match("^.+:(%d+)$")),
	}, peer_mt)
end

local no_handler = function(...) end
local handle = remote.wrap(function(peer, e)
	local handler = remote.handlers[e.name] or no_handler
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

function remote.receive(event)
	local e = MessagePack.unpack(event.data)

	if e.name then
		return handle(event.peer, e)
	end

	if e.id and tasks[e.id] then
		return tasks[e.id](_unpack(e, 1, 8))
	end
end

remote.handlers = {}

return remote
