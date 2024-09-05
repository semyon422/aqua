local socket_url = require("socket.url")
local IHandler = require("web.IHandler")

---@class web.RouterContext: web.HandlerContext
---@field path_params {[string]: string}
local RouterContext = {}

---@class web.RouterHandler: web.IHandler
---@operator call: web.RouterHandler
local RouterHandler = IHandler + {}

---@param router web.Router
function RouterHandler:new(router)
	self.router = router
end

---@param req web.IRequest
---@param res web.IResponse
---@param ctx web.RouterContext
function RouterHandler:handle(req, res, ctx)
	local parsed_url = socket_url.parse(req.uri)

	local path_params, _ctx = self.router:handle(parsed_url.path, req.method)
	if not path_params or not _ctx then
		error("route not found '" .. tostring(req.uri) .. "'")
	end

	ctx.path_params = path_params
	for k, v in pairs(_ctx) do
		ctx[k] = v
	end
end

return RouterHandler
