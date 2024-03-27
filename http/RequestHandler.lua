local class = require("class")
local socket_url = require("socket.url")
local http_util = require("http_util")
local table_util = require("table_util")

---@class http.RequestHandler
---@operator call: http.RequestHandler
local RequestHandler = class()

function RequestHandler:get_body_params(req, body_handler_name)
	local body_params = {}
	if body_handler_name then
		local body_handler = self.body_handlers[body_handler_name]
		body_params = body_handler(req.headers["Content-Type"])
	end
	return body_params
end

function RequestHandler:handle(req)
	local parsed_url = socket_url.parse(req.uri)

	local path_params, route_config = self.router:handle(parsed_url.path, req.method)
	if not route_config then
		error("route not found '" .. tostring(req.uri) .. "'")
	end
	local usecase_name, results, body_handler_name, input_conv_name = unpack(route_config)

	local params = {}
	table_util.copy(http_util.decode_query_string(parsed_url.query), params)
	table_util.copy(self:get_body_params(req, body_handler_name), params)
	table_util.copy(path_params, params)

	if input_conv_name then
		local input_conv = self.input_converters[input_conv_name]
		input_conv(params)
	end

	params.ip = req.headers["X-Real-IP"]
	self.session_handler:decode(params, req.headers)

	self.models:select(params, {session_user = {"users", {id = {"session", "user_id"}}, "user_roles"}})

	local usecase = self.usecases[usecase_name]
	local result_type, result = usecase:handle(params)

	local code_view_headers = results[result_type] or self.default_results[result_type]
	assert(code_view_headers, tostring(result_type))
	local code, view_config, headers = unpack(code_view_headers)

	result.config = self.config

	local res_body = ""
	if view_config then
		res_body = self.views:render(view_config, result)
	end
	if type(headers) == "function" then
		headers = headers(result)
	end
	headers = headers or {}

	self.session_handler:encode(params, headers)

	return code or 200, headers, res_body
end

return RequestHandler
