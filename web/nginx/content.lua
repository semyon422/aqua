-- lua entry thread aborted:
-- runtime error: /opt/openresty/lualib/resty/core/base.lua:80:
-- loop or previous error loading module '<mod_name>'
-- bug?

local orig_require_name, orig_require_value = debug.getupvalue(require, 4)
if orig_require_name == "orig_require" then
	require = orig_require_value
end

local NginxRequest = require("web.nginx.NginxRequest")
local NginxReqSocket = require("web.nginx.NginxReqSocket")
local Response = require("web.http.Response")

---@type web.NginxConfig
local config = require("nginx_config")

local function run()
	---@type fun(req: web.IRequest, res: web.IResponse, ip: string)
	local handle = require(config.handler)

	local soc = NginxReqSocket()
	local req = NginxRequest(soc)
	local res = Response(soc, "w")

	req:receive_headers()

	local ip = soc:getpeername()
	if config.proxied then
		ip = assert(req.headers:get("X-Real-IP"), "missing real ip")
	end

	return handle(req, res, ip)
end

return run
