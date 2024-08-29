local socket = require("socket")
local class = require("class")
local table_util = require("table_util")

---@class http.TcpServer
---@operator call: http.TcpServer
local TcpServer = class()

---@param ip string
---@param port integer
---@param client_handler function
function TcpServer:new(ip, port, client_handler)
	self.ip = ip
	self.port = port
	self.client_handler_func = function(client)
		return client_handler(client)
	end
end

function TcpServer:load()
	local soc = assert(socket.tcp4())
	self.soc = soc

	assert(soc:setoption("reuseaddr", true))
	assert(soc:bind(self.ip, self.port))
	assert(soc:listen(1024))
	assert(soc:settimeout(0))

	---@type TCPSocket[]
	self.recvt = {}
	table.insert(self.recvt, soc)
end

---@type {[TCPSocket]: thread}
local recv_coro = {}

---@param client TCPSocket
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

	local index = table_util.indexof(self.recvt, client)
	table.remove(self.recvt, index)
end

function TcpServer:handle_accept()
	local client, err = self.soc:accept()  -- timeout | ?
	if err then
		if err ~= "timeout" then
			error(err)
		end
		return
	end
	table.insert(self.recvt, client)
	client:settimeout(0)
end

---@param timeout number
function TcpServer:update(timeout)
	local rclients, _, err = socket.select(self.recvt, nil, timeout)  -- timeout | select failed
	if err then
		if err ~= "timeout" then
			error(err)
		end
		return
	end

	local soc = self.soc
	if rclients[soc] then
		self:handle_accept()
	end

	for _, client in ipairs(rclients) do
		if client ~= soc then
			self:handle_client(client)
		end
	end
end

return TcpServer
