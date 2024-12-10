local IHandler = require("web.framework.IHandler")

---@class web.AnonHandler: web.IHandler
---@operator call: web.AnonHandler
local AnonHandler = IHandler + {}

---@param handle fun(req: web.IRequest, res: web.IResponse, ctx: web.HandlerContext)
function AnonHandler:new(handle)
	self._handle = handle
end

---@param req web.IRequest
---@param res web.IResponse
---@param ctx web.ConverterContext
function AnonHandler:handle(req, res, ctx)
	self._handle(req, res, ctx)
end

return AnonHandler
