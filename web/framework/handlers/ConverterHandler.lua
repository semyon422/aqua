local IHandler = require("web.framework.IHandler")

---@class web.ConverterContext: web.HandlerContext
---@field input_conv_name string
local ConverterContext = {}

---@class web.ConverterHandler: web.IHandler
---@operator call: web.ConverterHandler
local ConverterHandler = IHandler + {}

---@param input_converters table
function ConverterHandler:new(input_converters)
	self.input_converters = input_converters
end

---@param req web.IRequest
---@param res web.IResponse
---@param ctx web.ConverterContext
function ConverterHandler:handle(req, res, ctx)
	if ctx.input_conv_name then
		local input_conv = self.input_converters[ctx.input_conv_name]
		input_conv(ctx)
	end
end

return ConverterHandler
