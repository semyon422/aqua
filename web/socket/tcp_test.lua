-- same tests as for LineAllDecorator
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
function test.receive_size_exact(t)
	local soc, client, server = new_server_client()

	client:send("qwe")
	client:close()

	t:tdeq({soc:receive(3)}, {"qwe"})
	t:tdeq({soc:receive(100)}, {nil, "closed", ""})
	t:tdeq({soc:receive(100)}, {nil, "closed", ""})

	server:close()
end

---@param t testing.T
function test.receive_size_more(t)
	local soc, client, server = new_server_client()

	client:send("qwe")
	client:close()

	t:tdeq({soc:receive(4)}, {nil, "closed", "qwe"})
	t:tdeq({soc:receive(100)}, {nil, "closed", ""})
	t:tdeq({soc:receive(100)}, {nil, "closed", ""})

	server:close()
end

---@param t testing.T
function test.receive_size_exact_timeout(t)
	local soc, client, server = new_server_client()

	client:send("qwe")

	t:tdeq({soc:receive(4)}, {nil, "timeout", "qwe"})

	client:send("rty")
	client:close()

	t:tdeq({soc:receive(3)}, {"rty"})
	t:tdeq({soc:receive(100)}, {nil, "closed", ""})
	t:tdeq({soc:receive(100)}, {nil, "closed", ""})

	server:close()
end

---@param t testing.T
function test.receive_line(t)
	local soc, client, server = new_server_client()

	client:send("qw\re\r\nr\rty")

	t:tdeq({soc:receive("*l")}, {"qwe"})

	client:send("asd\r\nfgh")
	client:close()

	t:tdeq({soc:receive("*l")}, {"rtyasd"})
	t:tdeq({soc:receive("*l")}, {nil, "closed", "fgh"})
	t:tdeq({soc:receive("*l")}, {nil, "closed", ""})
	t:tdeq({soc:receive("*l")}, {nil, "closed", ""})

	server:close()
end

---@param t testing.T
function test.receive_line_timeout(t)
	local soc, client, server = new_server_client()

	client:send("qw\re\r\nr\rty")

	t:tdeq({soc:receive("*l")}, {"qwe"})
	t:tdeq({soc:receive("*l")}, {nil, "timeout", "rty"})

	client:send("asd\r\nfgh")
	client:close()

	t:tdeq({soc:receive("*l")}, {"asd"})
	t:tdeq({soc:receive("*l")}, {nil, "closed", "fgh"})
	t:tdeq({soc:receive("*l")}, {nil, "closed", ""})
	t:tdeq({soc:receive("*l")}, {nil, "closed", ""})

	server:close()
end

---@param t testing.T
function test.receive_all(t)
	local soc, client, server = new_server_client()

	client:send("qwerty")
	client:close()

	t:tdeq({soc:receive("*a")}, {"qwerty"})
	t:tdeq({soc:receive("*a")}, {nil, "closed", ""})
	t:tdeq({soc:receive("*a")}, {nil, "closed", ""})

	server:close()
end

---@param t testing.T
function test.receive_all_timeout(t)
	local soc, client, server = new_server_client()

	client:send("qwe")

	t:tdeq({soc:receive("*a")}, {nil, "timeout", "qwe"})

	client:send("rty")
	client:close()

	t:tdeq({soc:receive("*a")}, {"rty"})
	t:tdeq({soc:receive("*a")}, {nil, "closed", ""})
	t:tdeq({soc:receive("*a")}, {nil, "closed", ""})

	server:close()
end

---@param t testing.T
function test.remainder_all(t)
	local soc, client, server = new_server_client()

	client:send("qw\re\r\nr\rty")

	t:tdeq({soc:receive("*l")}, {"qwe"})

	client:send("asd\r\nfgh")
	client:close()

	t:tdeq({soc:receive("*a")}, {"r\rtyasd\r\nfgh"})
	t:tdeq({soc:receive("*a")}, {nil, "closed", ""})
	t:tdeq({soc:receive("*a")}, {nil, "closed", ""})

	server:close()
end

---@param t testing.T
function test.remainder_size(t)
	local soc, client, server = new_server_client()

	client:send("qw\re\r\nr\rty")

	t:tdeq({soc:receive("*l")}, {"qwe"})

	t:tdeq({soc:receive(1)}, {"r"})
	t:tdeq({soc:receive(1)}, {"\r"})

	client:send("asd\r\nfgh")
	client:close()

	t:tdeq({soc:receive(3)}, {"tya"})
	t:tdeq({soc:receive(100)}, {nil, "closed", "sd\13\nfgh"})
	t:tdeq({soc:receive("*a")}, {nil, "closed", ""})
	t:tdeq({soc:receive("*a")}, {nil, "closed", ""})

	server:close()
end

return test
