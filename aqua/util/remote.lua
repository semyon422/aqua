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
local task_timeouts = {}

local run = function(peer, name, ...)
	local c = coroutine.running()
	if not c then
		error("attempt to yield from outside a coroutine")
	end

	event_id = event_id + 1
	local id = event_id

	local q, w, e, r, t, y, u, i = ...
	peer:send(MessagePack.pack({
		id = id,
		name = name,
		q, w, e, r, t, y, u, i
	}))

	tasks[id] = function(...)
		tasks[id] = nil
		task_timeouts[id] = nil
		q, w, e, r, t, y, u, i = ...
		assert(coroutine.resume(c))
	end
	task_timeouts[id] = os.time() + timeout
	coroutine.yield()

	return q, w, e, r, t, y, u, i
end

local peer_mt = {
	__index = function(t, name)
		return rawget(t, name) or function(...)
			return run(t.peer, name, ...)
		end
	end,
}
remote.peer = function(peer)
	return setmetatable({
		peer = peer,
		id = tostring(peer),
	}, peer_mt)
end

local handle = remote.wrap(function(peer, e)
	local handler = remote.handlers[e.name]
	local a, s, d, f, g, h, j, k
	if handler then
		a, s, d, f, g, h, j, k = handler(remote.peer(peer), e[1], e[2], e[3], e[4], e[5], e[6], e[7], e[8])
	end
	peer:send(MessagePack.pack({
		id = e.id,
		a, s, d, f, g, h, j, k
	}))
end)

function remote.update()
	local time = os.time()
	for id, t in pairs(task_timeouts) do
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

	local task = tasks[e.id]
	if task then
		task(e[1], e[2], e[3], e[4], e[5], e[6], e[7], e[8])
	end
end

remote.handlers = {}

return remote
