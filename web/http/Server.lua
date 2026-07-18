local class = require("class")

local CosocketServer = require("web.luasocket.CosocketServer")
local ExtendedSocket = require("web.socket.ExtendedSocket")
local Request = require("web.http.Request")
local Response = require("web.http.Response")

---@class web.HttpServerOptions: web.CosocketServerOptions

---@class web.HttpServer
---@operator call: web.HttpServer
---@field handler fun(req: web.Request, res: web.Response, ip: string, port: integer)
---@field tcp_server web.CosocketServer
local Server = class()

---@param scheduler web.CosocketScheduler
---@param handler fun(req: web.Request, res: web.Response, ip: string, port: integer)
---@param options web.HttpServerOptions?
function Server:new(scheduler, handler, options)
	self.handler = handler
	self.tcp_server = CosocketServer(scheduler, function(client, ip, port)
		self:handleClient(client, ip, port)
	end, options)
end

---@param client web.CosocketTcpSocket
---@param ip string
---@param port integer
function Server:handleClient(client, ip, port)
	local soc = ExtendedSocket(client)
	local req = Request(soc, "r")
	local res = Response(soc, "w")
	local ok = req:receive_headers()
	if not ok then
		return
	end
	res.headers:set("Connection", "close")
	self.handler(req, res, ip, port)
end

---@param host string
---@param port integer
---@return true?
---@return string?
function Server:start(host, port)
	return self.tcp_server:start(host, port)
end

function Server:stop()
	self.tcp_server:stop()
end

---@return string?
---@return integer?
function Server:getAddress()
	return self.tcp_server:getAddress()
end

return Server
