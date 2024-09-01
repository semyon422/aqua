local IHandler = require("web.IHandler")
local socket_url = require("socket.url")

---@class web.RouterContext: web.HandlerContext
---@field path_params {[string]: string}
---@field usecase_name string
---@field body_handler_name string?
---@field input_conv_name string?
---@field page_name string?
local RouterContext = {}

---@class web.RouterHandler: web.IHandler
---@operator call: web.RouterHandler
local RouterHandler = IHandler + {}

---@param handler web.IHandler
---@param router http.Router
function RouterHandler:new(handler, router, default_results)
	self.handler = handler
	self.router = router
	self.default_results = default_results
end

---@param req web.IRequest
---@param res web.IResponse
---@param ctx web.HandlerContext
function RouterHandler:handle(req, res, ctx)
	---@cast ctx +web.RouterContext

	local parsed_url = socket_url.parse(req.uri)

	local path_params, route_config = self.router:handle(parsed_url.path, req.method)
	if not route_config then
		error("route not found '" .. tostring(req.uri) .. "'")
	end

	ctx.path_params = path_params
	ctx.usecase_name = route_config[1]
	local results = route_config[2]
	ctx.body_handler_name = route_config[3]
	ctx.input_conv_name = route_config[4]

	self.handler:handle(req, res, ctx)

	---@cast ctx +web.UsecaseContext
	local result_type = ctx.result_type
	local code_page_headers = results[result_type] or self.default_results[result_type]
	assert(code_page_headers, tostring(result_type))

	local code, page, headers = unpack(code_page_headers, 1, 3)
	ctx.page_name = page

	res.status = code
	if type(headers) == "function" then
		headers = headers(ctx)
	end
	res.headers = headers or {}
end

return RouterHandler
