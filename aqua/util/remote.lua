local MessagePack = require("MessagePack")

local remote = {}

function remote.wrap(f)
	return function(...)
		return coroutine.wrap(f)(...)
	end
end

local tasks = {}
local event_id = 0

local run = function(peer, name, ...)
	local c = coroutine.running()
	if not c then
		error("attempt to yield from outside a coroutine")
	end

	event_id = event_id + 1
	local q, w, e, r, t, y, u, i = ...
	peer:send(MessagePack.pack({
		id = event_id,
		name = name,
		q, w, e, r, t, y, u, i
	}))

	tasks[event_id] = function(...)
		tasks[event_id] = nil
		q, w, e, r, t, y, u, i = ...
		assert(coroutine.resume(c))
	end
	coroutine.yield()

	return q, w, e, r, t, y, u, i
end

local peer_mt = {
	__index = function(t, name)
		return function(...)
			return run(t.peer, name, ...)
		end
	end,
}
remote.peer = function(peer)
	return setmetatable({peer = peer}, peer_mt)
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
