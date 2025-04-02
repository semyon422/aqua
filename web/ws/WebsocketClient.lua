local class = require("class")
local socket_url = require("socket.url")

local Headers = require("web.http.Headers")
local Request = require("web.http.Request")
local Response = require("web.http.Response")

-- https://datatracker.ietf.org/doc/html/rfc6455#section-4.1

local default = {
	path = "/",
	scheme = "ws",
}

local scheme_ports = {
	ws = 80,
	wss = 443,
}

---@class web.WebsocketClient
---@operator call: web.WebsocketClient
local WebsocketClient = class()

---@param tcp_soc web.ITcpSocket
function WebsocketClient:new(tcp_soc)
	self.tcp_soc = tcp_soc
	self.headers = Headers()
end

---@param url string
---@return {req: web.IRequest, res: web.IResponse}?
---@return string?
function WebsocketClient:connect(url)
	url = url:gsub("#", "%23") -- no fragment in ws

	local parsed_url = socket_url.parse(url, default)

	local tcp_soc = self.tcp_soc
	local ok, err = tcp_soc:connect(parsed_url.host, parsed_url.port or scheme_ports[parsed_url.scheme])
	if not ok then
		return nil, err
	end

	if parsed_url.scheme == "wss" then
		ok, err = tcp_soc:sslhandshake()
		if not ok then
			return nil, err
		end
	end

	local req = Request(tcp_soc)

	req.uri = socket_url.build({
		path = parsed_url.path,
		params = parsed_url.params,
		query = parsed_url.query,
	})

	req.headers:set("Host", parsed_url.host)
	req.headers:copy(self.headers)

	local res = Response(tcp_soc)

	return {
		req = req,
		res = res,
	}
end

return WebsocketClient
