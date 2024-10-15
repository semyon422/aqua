-- same tests as for ExtendedSocket
-- disabled

do return end

local socket = require("socket")

local test = {}

local function new_server_client()
	local server = assert(socket.tcp4())

	assert(server:setoption("reuseaddr", true))
	assert(server:bind("*", 8888))
	assert(server:listen(1024))
	assert(server:settimeout(0))

	local client = assert(socket.tcp4())
	assert(client:connect("127.0.0.1", 8888))
	assert(client:settimeout(0))

	local peer = server:accept()
	peer:settimeout(0)

	return peer, client, server
end

---@param t testing.T
function test.all(t)
	---@type {[string]: function}
	local tpl = require("web.socket.socket_tests")

	for _, f in pairs(tpl) do
		local soc, client, server = new_server_client()
		f(t, soc, client)
		soc:close()
		client:close()
		server:close()
	end
end

return test
