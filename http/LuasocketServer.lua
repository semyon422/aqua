local class = require("class")

local TcpServer = require("http.TcpServer")
local AsyncSocket = require("web.socket.AsyncSocket")
local SocketRequest = require("web.socket.SocketRequest")
local SocketResponse = require("web.socket.SocketResponse")

---@class http.LuasocketServer
---@operator call: http.LuasocketServer
local LuasocketServer = class()

---@param ip string
---@param port integer
---@param handler web.IHandler
function LuasocketServer:new(ip, port, handler)
	self.tcp_server = TcpServer(ip, port, function(client)
		local soc = AsyncSocket(client)
		local req = SocketRequest(soc)
		local res = SocketResponse(soc)

		local ok, err = req:readHeaders()
		if not ok then
			return nil, err
		end

		handler:handle(req, res, {})
	end)
end

function LuasocketServer:load()
	self.tcp_server:load()
end

function LuasocketServer:update()
	self.tcp_server:update(0)
end

return LuasocketServer
