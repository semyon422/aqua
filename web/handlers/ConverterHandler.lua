local IHandler = require("web.IHandler")

---@class web.ConverterHandler: web.IHandler
---@operator call: web.ConverterHandler
local ConverterHandler = IHandler + {}

---@param handler web.IHandler
---@param input_converters table
function ConverterHandler:new(handler, input_converters)
	self.handler = handler
	self.input_converters = input_converters
end

---@param req web.IRequest
---@param res web.IResponse
---@param ctx web.RouterContext
function ConverterHandler:handle(req, res, ctx)
	if ctx.input_conv_name then
		local input_conv = self.input_converters[ctx.input_conv_name]
		input_conv(ctx)
	end

	self.handler:handle(req, res, ctx)
end

return ConverterHandler
