local WebsocketClient = require("web.ws.WebsocketClient")
local CosocketTcpSocket = require("web.luasocket.CosocketTcpSocket")
local LsTcpSocket = require("web.luasocket.LsTcpSocket")
local NginxTcpSocket = require("web.nginx.NginxTcpSocket")

local util = {}

---@class web.WebsocketClientOptions
---@field scheduler web.CosocketScheduler?
---@field ip_version 4|6?
---@field tcp_socket web.ITcpSocket?
---@field on_connected (fun(connection: web.WebsocketConnection))?

---@param options web.WebsocketClientOptions?
---@return 4|6
local function get_ip_version(options)
	if options and options.ip_version then
		return options.ip_version
	end
	return 4
end

---@param options web.WebsocketClientOptions?
---@return web.ITcpSocket
function util.tcp(options)
	if options and options.tcp_socket then
		return options.tcp_socket
	end

	if options and options.scheduler then
		return CosocketTcpSocket(options.scheduler, get_ip_version(options))
	end

	if ngx then
		return NginxTcpSocket()
	end

	return LsTcpSocket(get_ip_version(options))
end

---@param options web.WebsocketClientOptions?
---@return web.WebsocketClient
function util.client(options)
	return WebsocketClient(util.tcp(options))
end

return util
