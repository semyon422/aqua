local class = require("class")
local socket = require("socket")
local ssl = require("ssl")

local TcpUpdater = require("web.luasocket.TcpUpdater")
local ExtendedSocket = require("web.socket.ExtendedSocket")
local Request = require("web.http.Request")
local Response = require("web.http.Response")

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
		local soc = ExtendedSocket(client)
		soc.cosocket = true
		local req = Request(soc)
		local res = Response(soc)

		handler:handle(req, res, {})
		soc:close()
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
	assert(soc:settimeout(0))

	self.tcp_updater:addClient(soc, function(client)
		local soc = ExtendedSocket(client)
		soc.cosocket = true
		local req = Request(soc)
		local res = Response(soc)

		handler:handle(req, res, {})
		soc:close()
	end)
end

function LuasocketServer:update()
	self.tcp_updater:update(0)
end

return LuasocketServer
