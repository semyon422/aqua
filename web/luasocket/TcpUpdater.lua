local socket = require("socket")
local class = require("class")
local table_util = require("table_util")

---@class web.TcpUpdater
---@operator call: web.TcpUpdater
local TcpUpdater = class()

function TcpUpdater:new()
	---@type TCPSocket[]
	self.recvt = {}

	---@type TCPSocket[]
	self.sendt = {}

	---@type {[TCPSocket]: function}
	self.handlers = {}

	---@type {[TCPSocket]: string}
	self.soc_types = {}
end

---@param soc TCPSocket
---@param handler function
function TcpUpdater:addClient(soc, handler)
	self.soc_types[soc] = "client"
	self.handlers[soc] = handler
	table.insert(self.sendt, soc)
end

---@param soc TCPSocket
---@param handler function
function TcpUpdater:addServer(soc, handler)
	self.soc_types[soc] = "server"
	self.handlers[soc] = handler
	table.insert(self.recvt, soc)
end

---@param soc TCPSocket
function TcpUpdater:remove(soc)
	local index = table_util.indexof(self.recvt, soc)
	if index then
		table.remove(self.recvt, index)
	end
	local index = table_util.indexof(self.sendt, soc)
	if index then
		table.remove(self.sendt, index)
	end
end

---@param soc TCPSocket
function TcpUpdater:handle_accept(soc)
	local client, err = soc:accept() -- timeout | ?
	if err then
		if err ~= "timeout" then
			error(err)
		end
		return
	end
	client:settimeout(0)
	self.soc_types[client] = "client"
	self.handlers[client] = self.handlers[soc]
	table.insert(self.recvt, client)
end

---@type {[TCPSocket]: thread}
local recv_coro = {}

---@param soc TCPSocket
function TcpUpdater:handle_client(soc)
	if not recv_coro[soc] then
		recv_coro[soc] = coroutine.create(function()
			self.handlers[soc](soc)
		end)
	end

	self:remove(soc)

	local ok, timeout_on = assert(coroutine.resume(recv_coro[soc]))
	if coroutine.status(recv_coro[soc]) == "dead" then
		recv_coro[soc] = nil
		soc:close()
		return
	end

	if timeout_on == "read" then
		table.insert(self.recvt, soc)
	elseif timeout_on == "write" then
		table.insert(self.sendt, soc)
	end
end

---@param timeout number
function TcpUpdater:update(timeout)
	local rsocs, ssocs, err = socket.select(self.recvt, self.sendt, timeout) -- timeout | select failed
	if err then
		if err ~= "timeout" then
			error(err)
		end
		return
	end

	for _, socs in pairs({rsocs, ssocs}) do
		for _, soc in ipairs(socs) do
			if self.soc_types[soc] == "client" then
				self:handle_client(soc)
			else
				self:handle_accept(soc)
			end
		end
	end
end

return TcpUpdater
