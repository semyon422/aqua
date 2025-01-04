local class = require("class")
local socket_url = require("socket.url")

local Headers = require("web.http.Headers")
local ExtendedSocket = require("web.socket.ExtendedSocket")
local Request = require("web.http.Request")
local Response = require("web.http.Response")

local default = {
	path = "/",
	scheme = "http",
}

local scheme_ports = {
	http = 80,
	https = 443,
}

---@class web.HttpClient
---@operator call: web.HttpClient
local HttpClient = class()

HttpClient.user_agent = "aqua.web/1.0"

---@param tcp_soc web.ITcpSocket
function HttpClient:new(tcp_soc)
	self.tcp_soc = tcp_soc
	self.headers = Headers()
end

function HttpClient:close()
	self.tcp_soc:close()
end

---@param url string
---@return web.IRequest
---@return web.IResponse
function HttpClient:connect(url)
	local parsed_url = socket_url.parse(url, default)

	local tcp_soc = self.tcp_soc
	assert(tcp_soc:connect(parsed_url.host, parsed_url.port or scheme_ports[parsed_url.scheme]))

	if parsed_url.scheme == "https" then
		assert(tcp_soc:sslhandshake())
	end

	local soc = ExtendedSocket(tcp_soc)

	local req = Request(soc)

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

	local res = Response(soc)

	return req, res
end

return HttpClient
