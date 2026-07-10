local WebsocketClient = require("web.ws.WebsocketClient")
local CosocketTcpSocket = require("web.luasocket.CosocketTcpSocket")
local LsTcpSocket = require("web.luasocket.LsTcpSocket")
local NginxTcpSocket = require("web.nginx.NginxTcpSocket")
local table_util = require("table_util")

local util = {}

---@class web.SslParams
---@field mode string?
---@field protocol string?
---@field options string[]?
---@field verify string?
---@field cafile string?
---@field capath string?

---@class web.WebsocketClientOptions
---@field scheduler web.CosocketScheduler?
---@field ip_version 4|6?
---@field tcp_socket web.ITcpSocket?
---@field timeout number?
---@field ssl_params web.SslParams?
---@field on_connected (fun(connection: web.WebsocketConnection))?

---@param options web.WebsocketClientOptions?
---@return 4|6
local function get_ip_version(options)
	if options and options.ip_version then
		return options.ip_version
	end
	return 4
end

---@param tcp_socket web.ITcpSocket
---@param options web.WebsocketClientOptions?
---@return web.ITcpSocket
local function configure_tcp(tcp_socket, options)
	if not options then
		return tcp_socket
	end
	if options.timeout then
		tcp_socket:settimeout(options.timeout)
	end
	if options.ssl_params then
		tcp_socket.ssl_params = table_util.deepcopy(options.ssl_params)
	end
	return tcp_socket
end

---@param options web.WebsocketClientOptions?
---@return web.ITcpSocket
function util.tcp(options)
	---@type web.ITcpSocket
	local tcp_socket
	if options and options.tcp_socket then
		tcp_socket = options.tcp_socket
	elseif options and options.scheduler then
		tcp_socket = CosocketTcpSocket(options.scheduler, get_ip_version(options))
	elseif ngx then
		tcp_socket = NginxTcpSocket()
	else
		tcp_socket = LsTcpSocket(get_ip_version(options))
	end

	---@cast tcp_socket -?

	return configure_tcp(tcp_socket, options)
end

---@param options web.WebsocketClientOptions?
---@return web.WebsocketClient
function util.client(options)
	return WebsocketClient(util.tcp(options))
end

return util
