local class = require("class")
local socket = require("socket")
local ssl = require("ssl")

local TcpUpdater = require("web.socket.TcpUpdater")
local AsyncSocket = require("web.socket.AsyncSocket")
local SocketRequest = require("web.socket.SocketRequest")
local SocketResponse = require("web.socket.SocketResponse")

---@class web.LuasocketServer
---@operator call: web.LuasocketServer
local LuasocketServer = class()

function LuasocketServer:new()
	self.tcp_updater = TcpUpdater()
end

---@param ip string
---@param port integer
---@param handler web.IHandler
function LuasocketServer:server(ip, port, handler)
	local soc = assert(socket.tcp4())
	self.soc = soc

	assert(soc:setoption("reuseaddr", true))
	assert(soc:bind(ip, port))
	assert(soc:listen(1024))
	assert(soc:settimeout(0))

	self.tcp_updater:addServer(soc, function(client)
		local soc = AsyncSocket(client)
		local req = SocketRequest(soc)
		local res = SocketResponse(soc)

		local ok, err = req:readStatusLine()
		if not ok then
			return nil, err
		end

		local ok, err = req:readHeaders()
		if not ok then
			return nil, err
		end

		handler:handle(req, res, {})
	end)
end

---@param ip string
---@param port integer
---@param handler web.IHandler
function LuasocketServer:client(ip, port, handler)
	local soc = assert(socket.tcp4())
	assert(soc:connect(ip, port))
	assert(soc:settimeout(0))

	soc = ssl.wrap(soc, {
		mode = "client",
		protocol = "any",
		options = {"all", "no_sslv2", "no_sslv3", "no_tlsv1"},
		verify = "none",
	})
	soc:dohandshake()

	self.tcp_updater:addClient(soc, function(client)
		local soc = AsyncSocket(client)
		local req = SocketRequest(soc)
		local res = SocketResponse(soc)

		handler:handle(req, res, {})
	end)
end

function LuasocketServer:update()
	self.tcp_updater:update(0)
end

return LuasocketServer
