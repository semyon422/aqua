local CosocketScheduler = require("web.luasocket.CosocketScheduler")
local CosocketServer = require("web.luasocket.CosocketServer")

local test = {}

local FakeSocket = {}
FakeSocket.__index = FakeSocket

---@return table
function FakeSocket:new()
	return setmetatable({closed = false}, self)
end

function FakeSocket:settimeout() end

---@return string
---@return integer
function FakeSocket:getpeername()
	return "127.0.0.1", 1234
end

---@return true
function FakeSocket:close()
	self.closed = true
	return true
end

---@param t testing.T
function test.limits_active_clients(t)
	local scheduler = CosocketScheduler()
	local server = CosocketServer(scheduler, function()
		coroutine.yield()
	end, {max_clients = 1})
	local first = FakeSocket:new()
	local second = FakeSocket:new()

	t:eq(server:startClient(first), true)
	t:eq(server.active_clients, 1)
	t:eq(server:startClient(second), false)
	t:eq(server.active_clients, 1)
	t:eq(second.closed, true)

	server:stop()
	t:eq(server.active_clients, 0)
	t:eq(first.closed, true)
end

return test
