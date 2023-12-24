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

---@param peer table|userdata
---@param id number?
---@param ret boolean?
---@param ... any?
function remote.send(peer, id, ret, ...)
	peer:send(encode({
		id = id,
		ret = ret,
		n = select("#", ...),
		...
	}))
end

---@param peer table
---@param ... any?
function remote.callnr(peer, ...)
	remote.send(peer, nil, nil, ...)
end

---@param peer table
---@param ... any?
---@return any?...
function remote.call(peer, ...)
	local c = coroutine.running()
	if not c then
		error("attempt to yield from outside a coroutine")
	end

	event_id = event_id + 1
	local id = event_id

	remote.send(peer, id, nil, ...)

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

function remote.update()
	local time = os.time()
	for id, t in pairs(timeouts) do
		if t <= time then
			tasks[id](nil, "timeout")
		end
	end
end

---@param peer table|userdata
---@param e table
---@param handler function
local function handle(peer, e, handler)
	if not e.id then
		handler(peer, unpack(e, 1, e.n))
		return
	end
	remote.send(peer, e.id, true, handler(peer, unpack(e, 1, e.n)))
end
handle = remote.wrap(handle)

---@param data any
---@param peer table|userdata
---@param handler function
function remote.receive(data, peer, handler)
	local ok, e = pcall(decode, data)
	if not ok or type(e) ~= "table" then
		return
	end

	if e.ret and tasks[e.id] then
		tasks[e.id](unpack(e, 1, e.n))
	else
		handle(peer, e, handler)
	end
end

return remote
