local NginxRequest = require("web.nginx.NginxRequest")
local NginxReqSocket = require("web.nginx.NginxReqSocket")
local Response = require("web.http.Response")

---@type web.NginxConfig
local config = require("nginx_config")

local function run()
	---@type boolean, any
	local ok, err = xpcall(require, debug.traceback, config.handler)
	if not ok then
		error(err)
	end

	---@cast err fun(req: web.IRequest, res: web.IResponse, ip: string)
	local handle = err

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
