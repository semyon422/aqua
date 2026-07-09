local CosocketScheduler = require("web.luasocket.CosocketScheduler")
local WebsocketConnection = require("web.ws.WebsocketConnection")

local test = {}

---@param t testing.T
---@param connection web.WebsocketConnection
---@param condition fun(): boolean
local function pump_until(t, connection, condition)
	local limit = 10
	while not condition() do
		connection:update()
		limit = limit - 1
		t:assert(limit > 0)
	end
end

---@param t testing.T
function test.cosocket_reader(t)
	local time = 0
	local scheduler = CosocketScheduler(nil, function()
		return time
	end)
	local connection = WebsocketConnection({scheduler = scheduler})

	local client_payload
	---@type string[]
	local events = {}

	function connection.protocol:text(payload, fin)
		if fin then
			client_payload = payload
		end
	end

	connection.ws = {
		state = "open",
		getState = function(self)
			return self.state
		end,
		step = function(self)
			table.insert(events, "step")
			if not self.waited then
				self.waited = true
				t:assert(scheduler:sleep(0))
			end
			connection.protocol:text("hello from reader", true)
			self.state = "closed"
			return true
		end,
	}

	connection:startReader()
	t:tdeq(events, {"step"})
	t:eq(client_payload, nil)

	pump_until(t, connection, function()
		return client_payload ~= nil
	end)

	t:tdeq(events, {"step"})
	t:eq(client_payload, "hello from reader")
end

---@param t testing.T
function test.cosocket_send_serializes_writers(t)
	local connection = WebsocketConnection({scheduler = CosocketScheduler()})

	---@type string[]
	local events = {}

	connection.ws = {
		send = function(_, _opcode, payload)
			table.insert(events, "start:" .. payload)
			if payload == "first" then
				coroutine.yield("paused")
			end
			table.insert(events, "finish:" .. payload)
			return #payload
		end,
	}

	local first_co = coroutine.create(function()
		return connection:send("text", "first")
	end)
	t:tdeq({coroutine.resume(first_co)}, {true, "paused"})
	t:tdeq(events, {"start:first"})

	local second_co = coroutine.create(function()
		return connection:send("text", "second")
	end)
	t:tdeq({coroutine.resume(second_co)}, {true})
	t:eq(coroutine.status(second_co), "suspended")
	t:tdeq(events, {"start:first"})

	t:tdeq({coroutine.resume(first_co)}, {true, 5})
	t:eq(coroutine.status(second_co), "dead")
	t:tdeq(events, {
		"start:first",
		"finish:first",
		"start:second",
		"finish:second",
	})
end

return test
