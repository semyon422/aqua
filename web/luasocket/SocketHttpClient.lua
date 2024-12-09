local class = require("class")
local socket_url = require("socket.url")

local Headers = require("web.http.Headers")
local ExtendedSocket = require("web.socket.ExtendedSocket")
local SocketRequest = require("web.luasocket.SocketRequest")
local SocketResponse = require("web.luasocket.SocketResponse")

local default = {
	path = "/",
	scheme = "http",
}

local scheme_ports = {
	http = 80,
	https = 443,
}

---@class web.SocketHttpClient
---@operator call: web.SocketHttpClient
local SocketHttpClient = class()

SocketHttpClient.user_agent = "aqua.web/1.0"

---@param tcp_soc web.ITcpSocket
function SocketHttpClient:new(tcp_soc)
	self.tcp_soc = tcp_soc
	self.headers = Headers()
end

---@param url string
---@return web.IRequest
---@return web.IResponse
function SocketHttpClient:connect(url)
	local parsed_url = socket_url.parse(url, default)

	local tcp_soc = self.tcp_soc
	assert(tcp_soc:connect(parsed_url.host, parsed_url.port or scheme_ports[parsed_url.scheme]))

	if parsed_url.scheme == "https" then
		tcp_soc:sslhandshake()
	end

	local soc = ExtendedSocket(tcp_soc)

	local req = SocketRequest(soc)

	req.uri = socket_url.build({
		path = parsed_url.path,
		params = parsed_url.params,
		query = parsed_url.query,
		fragment = parsed_url.fragment,
	})

	req.headers:set("Host", parsed_url.host)
	req.headers:set("User-Agent", self.user_agent)
	req.headers:set("Connection", "close")

	req.headers:copy(self.headers)

	local res = SocketResponse(soc)

	return req, res
end

return SocketHttpClient
