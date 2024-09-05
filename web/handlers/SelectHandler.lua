local IHandler = require("web.IHandler")

---@class web.SelectHandler: web.IHandler
---@operator call: web.SelectHandler
local SelectHandler = IHandler + {}

---@param get_handler fun(ctx: web.HandlerContext): web.IHandler?
function SelectHandler:new(get_handler)
	self.get_handler = get_handler
end

---@param req web.IRequest
---@param res web.IResponse
---@param ctx web.ConverterContext
function SelectHandler:handle(req, res, ctx)
	local handler = self.get_handler(ctx)
	if handler then
		handler:handle(req, res, ctx)
	end
end

return SelectHandler
