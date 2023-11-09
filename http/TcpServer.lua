local socket = require("socket")
local class = require("class")

---@class http.TcpServer
---@operator call: http.TcpServer
local TcpServer = class()

function TcpServer:new(ip, port, client_handler)
	self.ip = ip
	self.port = port
	self.recvt = {}
	self.client_handler_func = function(client)
		return client_handler:handle_client(client)
	end
end

function TcpServer:load()
	self.server = assert(socket.tcp4())
	local server = self.server

	assert(server:setoption("reuseaddr", true))
	assert(server:bind(self.ip, self.port))
	assert(server:listen(1024))
	assert(server:settimeout(0))

	self.recvt = {}
	table.insert(self.recvt, server)
end

local recv_coro = {}
function TcpServer:handle_client(client)
	if not recv_coro[client] then
		recv_coro[client] = coroutine.create(self.client_handler_func)
	end

	assert(coroutine.resume(recv_coro[client], client))
	if coroutine.status(recv_coro[client]) ~= "dead" then
		return
	end
	recv_coro[client] = nil
	client:close()
	for i, v in ipairs(self.recvt) do
		if v == client then
			table.remove(self.recvt, i)
			return
		end
	end
end

function TcpServer:handle_accept()
	local client, err = self.server:accept()  -- timeout | ?
	if err then
		if err ~= "timeout" then
			error(err)
		end
		return
	end
	table.insert(self.recvt, client)
	client:settimeout(0)
end

function TcpServer:update(timeout)
	local rclients, _, err = socket.select(self.recvt, nil, timeout)  -- timeout | select failed
	if err then
		if err ~= "timeout" then
			error(err)
		end
		return
	end

	local server = self.server
	if rclients[server] then
		self:handle_accept()
	end

	for _, client in ipairs(rclients) do
		if client ~= server then
			self:handle_client(client)
		end
	end
end

return TcpServer
