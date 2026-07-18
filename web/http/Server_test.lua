local coext = require("coext")
local socket = require("socket")

local CosocketScheduler = require("web.luasocket.CosocketScheduler")
local Server = require("web.http.Server")
local http_util = require("web.http.util")

local test = {}

---@param t testing.T
function test.request_response_round_trip(t)
	local scheduler = CosocketScheduler()
	local server = Server(scheduler, function(req, res, ip)
		t:eq(req.method, "GET")
		t:eq(req.uri, "/health")
		t:eq(ip, "127.0.0.1")
		res:set_length(2)
		res:send("ok")
	end, {on_error = function(err) error(err) end})
	t:assert(server:start("127.0.0.1", 0))
	local _, port = server:getAddress()

	local response
	local request_error
	local request_thread = coext.detach(coroutine.create(function()
		response, request_error = http_util.request(("http://127.0.0.1:%d/health"):format(port), nil, {
			scheduler = scheduler,
			timeout = 1,
		})
	end))
	t:assert(coroutine.resume(request_thread))

	local deadline = socket.gettime() + 2
	while coroutine.status(request_thread) ~= "dead" do
		local ok, err = scheduler:update(0.01)
		if not ok and err then
			error(err)
		end
		t:assert(socket.gettime() < deadline)
	end
	server:stop()

	t:eq(request_error, nil)
	t:eq(response.status, 200)
	t:eq(response.body, "ok")
	t:eq(response.headers:get("Connection"), "close")
end

---@param t testing.T
function test.rejects_large_header_line(t)
	local scheduler = CosocketScheduler()
	local handled = false
	local server = Server(scheduler, function()
		handled = true
	end, {
		max_header_line_size = 32,
		on_error = function(err) error(err) end,
	})
	t:assert(server:start("127.0.0.1", 0))
	local _, port = server:getAddress()

	local response
	local request_error
	local request_thread = coext.detach(coroutine.create(function()
		response, request_error = http_util.request(("http://127.0.0.1:%d/health"):format(port), nil, {
			scheduler = scheduler,
			timeout = 1,
			headers = {["X-Large"] = string.rep("a", 64)},
		})
	end))
	t:assert(coroutine.resume(request_thread))

	local deadline = socket.gettime() + 2
	while coroutine.status(request_thread) ~= "dead" do
		local ok, err = scheduler:update(0.01)
		if not ok and err then
			error(err)
		end
		t:assert(socket.gettime() < deadline)
	end
	server:stop()

	t:eq(request_error, nil)
	t:eq(handled, false)
	t:eq(response.status, 431)
	t:eq(response.body, "")
end

return test
