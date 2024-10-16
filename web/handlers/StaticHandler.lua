local path_util = require("path_util")
local IHandler = require("web.IHandler")

---@class web.StaticContext: web.HandlerContext
---@field prefix string
---@field path_params {[string]: string}
local StaticContext = {}

---@class web.StaticHandler: web.IHandler
---@operator call: web.StaticHandler
local StaticHandler = IHandler + {}

---@param req web.IRequest
---@param res web.IResponse
---@param ctx web.StaticContext
function StaticHandler:handle(req, res, ctx)
	local f = assert(io.open(path_util.join(ctx.prefix, ctx.path_params.filename)))
	local data = f:read("*a")
	f:close()

	res.headers:add("Content-Length", #data)
	res:send(data)
end

return StaticHandler
