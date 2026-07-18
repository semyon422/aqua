local class = require("class")
local coext = require("coext")
local socket = require("socket")

local CosocketTcpSocket = require("web.luasocket.CosocketTcpSocket")

---@class web.CosocketServerOptions
---@field backlog integer?
---@field client_timeout number?
---@field max_clients integer?
---@field socket_factory (fun(): any)?
---@field on_error (fun(err: string))?

---@class web.CosocketServer
---@operator call: web.CosocketServer
---@field scheduler web.CosocketScheduler
---@field handler fun(client: web.CosocketTcpSocket, ip: string, port: integer)
---@field options web.CosocketServerOptions
---@field server any?
---@field accept_thread thread?
---@field client_threads {[thread]: true}
---@field active_clients integer
---@field host string?
---@field port integer?
---@field closed boolean
local CosocketServer = class()

---@param scheduler web.CosocketScheduler
---@param handler fun(client: web.CosocketTcpSocket, ip: string, port: integer)
---@param options web.CosocketServerOptions?
function CosocketServer:new(scheduler, handler, options)
	self.scheduler = scheduler
	self.handler = handler
	self.options = options or {}
	self.client_threads = {}
	self.active_clients = 0
	self.closed = true
end

---@param err any
function CosocketServer:reportError(err)
	local on_error = self.options.on_error
	if on_error then
		on_error(tostring(err))
	else
		print(("server error: %s"):format(err))
	end
end

---@param peer any
---@return boolean
function CosocketServer:startClient(peer)
	local max_clients = self.options.max_clients
	if max_clients and self.active_clients >= max_clients then
		peer:close()
		return false
	end

	local client = CosocketTcpSocket(self.scheduler, nil, peer)
	client:settimeout(self.options.client_timeout)
	local ip, port = client:getpeername()

	---@type thread
	local client_thread
	client_thread = coext.detach(coroutine.create(function()
		local ok, err = xpcall(self.handler, debug.traceback, client, ip, port)
		local close_ok, close_err = pcall(client.close, client)
		self.client_threads[client_thread] = nil
		self.active_clients = self.active_clients - 1
		if not ok then
			self:reportError(err)
		elseif not close_ok then
			self:reportError(close_err)
		end
	end))
	self.client_threads[client_thread] = true
	self.active_clients = self.active_clients + 1
	local ok, err = coroutine.resume(client_thread)
	if not ok then
		self.client_threads[client_thread] = nil
		self.active_clients = self.active_clients - 1
		client:close()
		self:reportError(err)
		return false
	end
	return true
end

function CosocketServer:acceptLoop()
	local server = assert(self.server)
	while not self.closed do
		local peer, err = server:accept()
		if peer then
			self:startClient(peer)
		elseif err == "timeout" then
			local ok
			ok, err = self.scheduler:waitRead(server)
			if not ok and not self.closed then
				self:reportError(err)
				return
			end
		else
			if not self.closed then
				self:reportError(err)
			end
			return
		end
	end
end

---@param host string
---@param port integer
---@return true?
---@return string?
function CosocketServer:start(host, port)
	if self.server then
		return nil, "server already started"
	end

	local socket_factory = self.options.socket_factory or socket.tcp4 or socket.tcp
	local server, err = socket_factory()
	if not server then
		return nil, err
	end

	local ok
	ok, err = server:setoption("reuseaddr", true)
	if not ok then
		server:close()
		return nil, err
	end
	ok, err = server:bind(host, port)
	if not ok then
		server:close()
		return nil, err
	end
	ok, err = server:listen(self.options.backlog or 16)
	if not ok then
		server:close()
		return nil, err
	end
	server:settimeout(0)

	local bound_host, bound_port = server:getsockname()
	self.server = server
	self.host = bound_host
	self.port = bound_port
	self.closed = false
	self.accept_thread = coext.detach(coroutine.create(function()
		self:acceptLoop()
	end))
	ok, err = coroutine.resume(self.accept_thread)
	if not ok then
		self:stop()
		return nil, err
	end
	return true
end

function CosocketServer:stop()
	self.closed = true
	local server = self.server
	self.server = nil
	if server then
		self.scheduler:closeSocket(server)
		server:close()
	end

	---@type thread[]
	local client_threads = {}
	for client_thread in pairs(self.client_threads) do
		table.insert(client_threads, client_thread)
	end
	for _, client_thread in ipairs(client_threads) do
		if coroutine.status(client_thread) ~= "dead" then
			self.scheduler:cancel(client_thread, "server stopped")
		end
	end
	self.client_threads = {}
	self.active_clients = 0
	self.accept_thread = nil
end

---@return string?
---@return integer?
function CosocketServer:getAddress()
	return self.host, self.port
end

return CosocketServer
