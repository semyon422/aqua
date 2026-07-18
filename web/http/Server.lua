local class = require("class")

local CosocketServer = require("web.luasocket.CosocketServer")
local ExtendedSocket = require("web.socket.ExtendedSocket")
local Request = require("web.http.Request")
local Response = require("web.http.Response")

---@class web.HttpServerOptions: web.CosocketServerOptions, web.HttpRequestLimits

---@class web.HttpServer
---@operator call: web.HttpServer
---@field handler fun(req: web.Request, res: web.Response, ip: string, port: integer)
---@field options web.HttpServerOptions
---@field tcp_server web.CosocketServer
local Server = class()

Server.max_request_line_size = 8192
Server.max_header_line_size = 8192
Server.max_header_size = 32768
Server.max_header_count = 100

---@param scheduler web.CosocketScheduler
---@param handler fun(req: web.Request, res: web.Response, ip: string, port: integer)
---@param options web.HttpServerOptions?
function Server:new(scheduler, handler, options)
	self.handler = handler
	self.options = options or {}
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
	res.headers:set("Connection", "close")
	local options = self.options
	local ok, err = req:receive_headers({
		max_request_line_size = options.max_request_line_size or self.max_request_line_size,
		max_header_line_size = options.max_header_line_size or self.max_header_line_size,
		max_header_size = options.max_header_size or self.max_header_size,
		max_header_count = options.max_header_count or self.max_header_count,
	})
	if not ok then
		if err == "closed" or err == "timeout" then
			return
		end
		if err == "line too long" or err == "headers too large" or err == "too many headers" then
			res.status = 431
		else
			res.status = 400
		end
		res:set_length(0)
		res:send_headers()
		return
	end
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
