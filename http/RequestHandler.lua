local class = require("class")
local socket_url = require("socket.url")
local http_util = require("http_util")
local table_util = require("table_util")

---@class http.RequestHandler
---@operator call: http.RequestHandler
local RequestHandler = class()

function RequestHandler:new(router, body_handlers, session_handler, uv_handler, before)
	self.router = router
	self.body_handlers = body_handlers
	self.session_handler = session_handler
	self.uv_handler = uv_handler
	self.before = before
end

function RequestHandler:handle(req)
	local parsed_url = socket_url.parse(req.uri)

	local path_params, route_config = self.router:handle(parsed_url.path, req.method)
	local usecase_name, results, body_handler_name = unpack(route_config)

	local body_params = {}
	if body_handler_name then
		local body_handler = self.body_handlers[body_handler_name]
		body_params = body_handler(req.headers["Content-Type"])
		print("body params: " .. tostring(body_params))
	end
	local query_params = http_util.decode_query_string(parsed_url.query)

	local params = {}
	table_util.copy(query_params, params)
	table_util.copy(body_params, params)
	table_util.copy(path_params, params)

	params.ip = req.headers["X-Real-IP"]

	self.session_handler:decode(params, req.headers)

	self.before(params)
	local code, headers, body = self.uv_handler:handle(params, usecase_name, results)

	self.session_handler:encode(params, req.headers)

	return code, headers, body
end

return RequestHandler
