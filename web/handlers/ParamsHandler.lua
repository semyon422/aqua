local IHandler = require("web.IHandler")
local socket_url = require("socket.url")
local table_util = require("table_util")
local http_util = require("http_util")

---@class web.ParamsContext: web.HandlerContext
---@field ip string
local ParamsContext = {}

---@class web.ParamsHandler: web.IHandler
---@operator call: web.ParamsHandler
local ParamsHandler = IHandler + {}

---@param handler web.IHandler
---@param body_handlers table
---@param input_converters table
function ParamsHandler:new(handler, body_handlers, input_converters)
	self.handler = handler
	self.body_handlers = body_handlers
	self.input_converters = input_converters
end

function ParamsHandler:get_body_params(req, body_handler_name)
	local body_params = {}
	if body_handler_name then
		local body_handler = self.body_handlers[body_handler_name]
		body_params = body_handler(req.headers["Content-Type"])
	end
	return body_params
end

---@param req web.IRequest
---@param res web.IResponse
---@param ctx web.RouterContext
function ParamsHandler:handle(req, res, ctx)
	---@cast ctx +web.ParamsContext

	local parsed_url = socket_url.parse(req.uri)

	table_util.copy(http_util.decode_query_string(parsed_url.query), ctx)
	table_util.copy(self:get_body_params(req, ctx.body_handler_name), ctx)
	table_util.copy(ctx.path_params, ctx)

	if ctx.input_conv_name then
		local input_conv = self.input_converters[ctx.input_conv_name]
		input_conv(ctx)
	end

	ctx.ip = req.headers["X-Real-IP"]

	self.handler:handle(req, res, ctx)
end

return ParamsHandler
