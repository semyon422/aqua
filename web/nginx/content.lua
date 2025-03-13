local NginxRequest = require("web.nginx.NginxRequest")
local NginxReqSocket = require("web.nginx.NginxReqSocket")
local Response = require("web.http.Response")

---@param handle fun(req: web.IRequest, res: web.IResponse)
local function run(handle)
	local soc = NginxReqSocket()
	local req = NginxRequest(soc)
	local res = Response(soc, "w")
	return handle(req, res)
end

return run
