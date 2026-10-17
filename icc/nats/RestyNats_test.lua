local test = {}

---@class nats.RestyFixture
---@field clients nats.FakeRestyClient[]
---@field events string[]
---@field receivers {[thread]: nats.FakeRestyClient}
---@field on_parse fun()?
---@field connect_error string?

---@class nats.FakeRestyClient: nats.Client
---@field receiving boolean
---@field close_count integer

---@return nats.RestyNats
---@return nats.RestyFixture
local function create()
	---@type nats.RestyFixture
	local ctx = {clients = {}, events = {}, receivers = {}}
	local client_module = {}
	---@return nats.Client?, string?
	function client_module.connect()
		if ctx.connect_error then return nil, ctx.connect_error end
		---@type nats.FakeRestyClient
		local cli = {
			socket_config = {keepalive = true},
			closing = false,
			receiving = false,
			close_count = 0,
			subscribers = {},
			subscriber_id_map = {},
			subscriber_id = 0,
			sock = {
				send = function(_, data) return #data end,
				receiveany = function()
					local thread = coroutine.running()
					local current = ctx.receivers[thread]
					current.receiving = true
					coroutine.yield()
					current.receiving = false
					return "message"
				end,
			},
			publish = function() return true end,
			subscribe = function() return true end,
			close = function(self)
				assert(not self.receiving, "close while receive is pending")
				assert(not self.socket_config.keepalive, "pooled subscribed socket")
				self.closing = true
				self.close_count = self.close_count + 1
				table.insert(ctx.events, "close")
			end,
		}
		table.insert(ctx.clients, cli)
		return cli
	end
	local fake_ngx = {
		worker = {exiting = function() return false end},
		thread = {
			spawn = function(callback)
				local receiver = coroutine.create(callback)
				ctx.receivers[receiver] = ctx.clients[#ctx.clients]
				assert(coroutine.resume(receiver))
				return receiver
			end,
			kill = function(receiver)
				ctx.receivers[receiver].receiving = false
				table.insert(ctx.events, "kill")
				return true
			end,
		},
	}
	local parser_module = {
		MESSAGE_TYPE = {PING = "PING", MSG = "MSG", HMSG = "HMSG"},
		new = function()
			return {parse = function()
				if ctx.on_parse then ctx.on_parse() end
			end}
		end,
	}
	local path = debug.getinfo(1, "S").source:sub(2):gsub("RestyNats_test.lua$", "RestyNats.lua")
	local loader = assert(loadfile(path))
	setfenv(loader, setmetatable({
		ngx = fake_ngx,
		print = function() end,
		require = function(name)
			if name == "resty.nats.client" then return client_module end
			if name == "resty.nats.protocols.parser" then return parser_module end
			if name == "resty.nats.protocols.unsub" then
				return {encode = function() return "UNSUB" end}
			end
			return require(name)
		end,
	}, {__index = _G}))
	local RestyNats = loader()
	return RestyNats(), ctx
end

---@param t testing.T
function test.close_cancels_receive_before_socket_and_never_pools(t)
	local nc, ctx = create()
	t:assert(nc:start())
	t:eq(nc:health(), true)
	t:eq(ctx.clients[1].receiving, true)
	nc:close()
	t:tdeq(ctx.events, {"kill", "close"})
	t:eq(nc:health(), false)
	t:eq(nc.receive_thread, nil)
	t:eq(nc.cli, nil)
	nc:close()
	t:eq(ctx.clients[1].close_count, 1)
end

---@param t testing.T
function test.unused_and_failed_connections_close_without_reconnecting(t)
	local nc, ctx = create()
	nc:close()
	t:eq(#ctx.clients, 0)
	ctx.connect_error = "unavailable"
	local cli, err = nc:start()
	t:eq(cli, nil)
	t:eq(err, "unavailable")
	nc:close()
	t:eq(nc.connect_failed, false)
	ctx.connect_error = nil
	t:assert(nc:start())
	nc:close()
	t:eq(#ctx.clients, 1)
end

---@param t testing.T
function test.reconnect_after_close_owns_new_receiver(t)
	local nc, ctx = create()
	t:assert(nc:start())
	local first = nc.receive_thread
	nc:close()
	t:assert(nc:start())
	t:ne(nc.receive_thread, first)
	t:eq(#ctx.clients, 2)
	t:eq(nc:health(), true)
	nc:close()
	t:tdeq(ctx.events, {"kill", "close", "kill", "close"})
end

---@param t testing.T
function test.close_from_receive_callback_does_not_kill_itself(t)
	local nc, ctx = create()
	t:assert(nc:start())
	ctx.on_parse = function() nc:close() end
	local receiver = assert(nc.receive_thread)
	t:assert(coroutine.resume(receiver))
	t:eq(coroutine.status(receiver), "dead")
	t:tdeq(ctx.events, {"close"})
	t:eq(nc:health(), false)
end

return test
