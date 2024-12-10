local IHandler = require("web.framework.IHandler")

---@class web.MergeHandler: web.IHandler
---@operator call: web.MergeHandler
local MergeHandler = IHandler + {}

---@param handler web.IHandler
---@param ctx web.HandlerContext
function MergeHandler:new(handler, ctx)
	self.handler = handler
	self.ctx = ctx
end

---@param req web.IRequest
---@param res web.IResponse
---@param ctx web.HandlerContext
function MergeHandler:handle(req, res, ctx)
	for k, v in pairs(self.ctx) do
		ctx[k] = v
	end
	self.handler:handle(req, res, ctx)
end

return MergeHandler
