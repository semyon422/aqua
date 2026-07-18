local class = require("class")
local socket_url = require("socket.url")

local HttpServer = require("web.http.Server")
local JsonSchema = require("mcp.JsonSchema")
local json = require("web.json")

---@class mcp.ToolAnnotations
---@field readOnlyHint boolean?
---@field destructiveHint boolean?
---@field idempotentHint boolean?
---@field openWorldHint boolean?

---@class mcp.Tool
---@field name string
---@field description string?
---@field input_schema table
---@field output_schema table?
---@field annotations mcp.ToolAnnotations?
---@field execute fun(self: mcp.Tool, args: {[string]: any}): string, boolean?, table?

---@class mcp.Implementation
---@field name string
---@field version string
---@field description string?

---@class mcp.ServerOptions
---@field host string?
---@field port integer?
---@field path string?
---@field token string?
---@field max_body_size integer?
---@field client_timeout number?
---@field max_clients integer?
---@field on_error (fun(err: string))?
---@field server_info mcp.Implementation?

---@class mcp.Server
---@operator call: mcp.Server
---@field tools mcp.Tool[]
---@field tools_by_name {[string]: mcp.Tool}
---@field options mcp.ServerOptions
---@field http_server web.HttpServer
local Server = class()

Server.protocol_version = "2025-11-25"
Server.supported_versions = {
	["2025-03-26"] = true,
	["2025-06-18"] = true,
	["2025-11-25"] = true,
}
Server.host = "127.0.0.1"
Server.port = 38679
Server.path = "/mcp"
Server.max_body_size = 1024 * 1024

---@param scheduler web.CosocketScheduler
---@param tools mcp.Tool[]
---@param options mcp.ServerOptions?
function Server:new(scheduler, tools, options)
	self.options = options or {}
	self.tools = tools
	self.tools_by_name = {}
	for _, tool in ipairs(tools) do
		assert(type(tool.name) == "string", "MCP tool name must be a string")
		assert(type(tool.input_schema) == "table", "MCP tool input_schema must be a table")
		assert(tool.output_schema == nil or type(tool.output_schema) == "table", "MCP tool output_schema must be a table")
		assert(type(tool.execute) == "function", "MCP tool execute must be a function")
		assert(not self.tools_by_name[tool.name], "duplicate MCP tool: " .. tool.name)
		self.tools_by_name[tool.name] = tool
	end
	self.http_server = HttpServer(scheduler, function(req, res, ip, port)
		self:handleHttp(req, res, ip, port)
	end, {
		client_timeout = self.options.client_timeout or 10,
		max_clients = self.options.max_clients or 16,
		on_error = self.options.on_error,
	})
end

---@param res web.Response
---@param status integer
---@param body string?
---@param content_type string?
---@return integer?
---@return string?
local function send_response(res, status, body, content_type)
	body = body or ""
	res.status = status
	res:set_length(#body)
	if content_type then
		res.headers:set("Content-Type", content_type)
	end
	if body == "" then
		return res:send_headers()
	end
	return res:send(body)
end

---@param id any?
---@param code integer
---@param message string
---@param data any?
---@return table
local function rpc_error(id, code, message, data)
	---@type {code: integer, message: string, data: any?}
	local err = {code = code, message = message}
	if data ~= nil then
		err.data = data
	end
	return {jsonrpc = "2.0", id = id, error = err}
end

---@param id any
---@param result table
---@return table
local function rpc_result(id, result)
	return {jsonrpc = "2.0", id = id, result = result}
end

---@param req web.Request
---@return boolean
function Server:isAuthorized(req)
	local token = self.options.token
	return not token or token == "" or req.headers:get("Authorization") == "Bearer " .. token
end

---@param req web.Request
---@return boolean
function Server:isOriginAllowed(req)
	-- Browser origins are rejected by default. Native MCP clients omit Origin,
	-- which prevents a remote web page from reaching this loopback service.
	return req.headers:get("Origin") == nil
end

---@param message table
---@return table?
function Server:dispatch(message)
	local id = message.id
	local method = message.method
	if type(method) ~= "string" or message.jsonrpc ~= "2.0" then
		return rpc_error(id, -32600, "Invalid Request")
	end
	if id ~= nil and type(id) ~= "string" and type(id) ~= "number" then
		return rpc_error(nil, -32600, "Invalid Request")
	end

	if method == "notifications/initialized" or method == "notifications/cancelled" then
		return
	end
	if id == nil then
		return
	end

	if method == "initialize" then
		local params = message.params
		if type(params) ~= "table"
			or type(params.protocolVersion) ~= "string"
			or type(params.capabilities) ~= "table"
			or type(params.clientInfo) ~= "table"
			or type(params.clientInfo.name) ~= "string"
			or type(params.clientInfo.version) ~= "string"
		then
			return rpc_error(id, -32602, "Invalid initialize parameters")
		end
		local requested = params.protocolVersion
		local protocol_version = self.supported_versions[requested] and requested or self.protocol_version
		return rpc_result(id, {
			protocolVersion = protocol_version,
			capabilities = {tools = {listChanged = false}},
			serverInfo = self.options.server_info or {
				name = "aqua-mcp",
				version = "dev",
			},
		})
	elseif method == "ping" then
		if message.params ~= nil and type(message.params) ~= "table" then
			return rpc_error(id, -32602, "Invalid ping parameters")
		end
		return rpc_result(id, {})
	elseif method == "tools/list" then
		local params = message.params
		if params ~= nil and (type(params) ~= "table" or (params.cursor ~= nil and type(params.cursor) ~= "string")) then
			return rpc_error(id, -32602, "Invalid tools/list parameters")
		end
		---@type table[]
		local tools = {}
		for _, tool in ipairs(self.tools) do
			table.insert(tools, {
				name = tool.name,
				description = tool.description,
				inputSchema = tool.input_schema,
				outputSchema = tool.output_schema,
				annotations = tool.annotations,
			})
		end
		return rpc_result(id, {tools = tools})
	elseif method == "tools/call" then
		local params = message.params
		if type(params) ~= "table" or type(params.name) ~= "string" then
			return rpc_error(id, -32602, "Invalid tools/call parameters")
		end
		local tool = self.tools_by_name[params.name]
		if not tool then
			return rpc_error(id, -32602, "Unknown tool: " .. params.name)
		end
		local arguments = params.arguments or {}
		if type(arguments) ~= "table" then
			return rpc_error(id, -32602, "Tool arguments must be an object")
		end
		local valid, validation_err = JsonSchema.validate(tool.input_schema, arguments)
		if not valid then
			return rpc_error(id, -32602, "Invalid tool arguments", validation_err)
		end

		local ok, output, is_error, structured_content = xpcall(tool.execute, debug.traceback, tool, arguments)
		if not ok then
			return rpc_result(id, {
				content = {{type = "text", text = tostring(output)}},
				isError = true,
			})
		end
		if type(output) ~= "string" then
			return rpc_result(id, {
				content = {{type = "text", text = "tool returned a non-string result"}},
				isError = true,
			})
		end
		if structured_content ~= nil and type(structured_content) ~= "table" then
			return rpc_result(id, {
				content = {{type = "text", text = "tool returned non-table structured content"}},
				isError = true,
			})
		end
		if tool.output_schema then
			if structured_content == nil then
				return rpc_result(id, {
					content = {{type = "text", text = "tool did not return required structured content"}},
					isError = true,
				})
			end
			local valid_output, output_err = JsonSchema.validate(tool.output_schema, structured_content)
			if not valid_output then
				return rpc_result(id, {
					content = {{type = "text", text = "invalid structured tool output: " .. output_err}},
					isError = true,
				})
			end
		end
		return rpc_result(id, {
			content = {{type = "text", text = output}},
			structuredContent = structured_content,
			isError = is_error == true,
		})
	end

	return rpc_error(id, -32601, "Method not found: " .. method)
end

---@param messages table[]
---@return table[]|table?
function Server:dispatchBatch(messages)
	if #messages == 0 then
		return rpc_error(nil, -32600, "Invalid Request")
	end
	for _, message in ipairs(messages) do
		if type(message) == "table" and message.method == "initialize" then
			return rpc_error(nil, -32600, "Only one initialization request is allowed")
		end
	end

	---@type table[]
	local responses = {}
	for _, message in ipairs(messages) do
		local response
		if type(message) == "table" then
			response = self:dispatch(message)
		else
			response = rpc_error(nil, -32600, "Invalid Request")
		end
		if response then
			table.insert(responses, response)
		end
	end
	if #responses == 0 then
		return
	end
	return responses
end

---@param host string
---@return boolean
local function is_loopback(host)
	return host == "localhost" or host == "::1" or host:match("^127%.") ~= nil
end

---@param messages table[]
---@return boolean
local function has_initialize(messages)
	for _, message in ipairs(messages) do
		if type(message) == "table" and message.method == "initialize" then
			return true
		end
	end
	return false
end

---@param req web.Request
---@param res web.Response
---@param ip string
---@param port integer
function Server:handleHttp(req, res, ip, port)
	local parsed_uri = socket_url.parse(req.uri)
	if not parsed_uri or parsed_uri.path ~= (self.options.path or self.path) then
		send_response(res, 404, "not found", "text/plain")
		return
	end
	if not self:isOriginAllowed(req) then
		send_response(res, 403, json.encode(rpc_error(nil, -32000, "Invalid Origin")), "application/json")
		return
	end
	if not self:isAuthorized(req) then
		res.headers:set("WWW-Authenticate", "Bearer")
		send_response(res, 401, "unauthorized", "text/plain")
		return
	end
	if req.method == "GET" or req.method == "DELETE" then
		res.headers:set("Allow", "POST")
		send_response(res, 405, "method not allowed", "text/plain")
		return
	elseif req.method ~= "POST" then
		send_response(res, 405, "method not allowed", "text/plain")
		return
	end
	local accept = (req.headers:get("Accept") or ""):lower()
	if not accept:find("application/json", 1, true) or not accept:find("text/event-stream", 1, true) then
		send_response(res, 406, "Accept must include application/json and text/event-stream", "text/plain")
		return
	end

	local content_type = req.headers:get("Content-Type") or ""
	local media_type = content_type:lower():match("^%s*([^;%s]+)")
	if media_type ~= "application/json" then
		send_response(res, 415, "Content-Type must be application/json", "text/plain")
		return
	end
	local content_length = tonumber(req.headers:get("Content-Length"))
	if not content_length then
		send_response(res, 411, "Content-Length required", "text/plain")
		return
	end
	if content_length > (self.options.max_body_size or self.max_body_size) then
		send_response(res, 413, "request body too large", "text/plain")
		return
	end

	local body, receive_err = req:receive("*a")
	if not body then
		send_response(res, 400, tostring(receive_err), "text/plain")
		return
	end
	local message, decode_err = json.decode_safe(body)
	if type(message) ~= "table" then
		send_response(res, 400, json.encode(rpc_error(nil, -32700, "Parse error", decode_err)), "application/json")
		return
	end

	local is_batch = body:match("^%s*%[") ~= nil
	local initializing = is_batch and has_initialize(message) or message.method == "initialize"
	local requested_protocol = req.headers:get("MCP-Protocol-Version")
	if not initializing and requested_protocol and not self.supported_versions[requested_protocol] then
		send_response(res, 400, json.encode(rpc_error(nil, -32000, "Unsupported MCP protocol version: " .. requested_protocol)), "application/json")
		return
	end

	local response
	if is_batch then
		response = self:dispatchBatch(message)
	else
		response = self:dispatch(message)
	end
	if not response then
		send_response(res, 202)
		return
	end
	local response_protocol = requested_protocol or self.protocol_version
	if initializing then
		response_protocol = not is_batch and response.result and response.result.protocolVersion or self.protocol_version
	end
	res.headers:set("MCP-Protocol-Version", response_protocol)
	res.headers:set("Cache-Control", "no-store")
	send_response(res, 200, json.encode(response), "application/json")
end

---@return true?
---@return string?
function Server:start()
	local host = self.options.host or self.host
	local token = self.options.token
	if not is_loopback(host) and (not token or token == "") then
		return nil, "MCP authentication token is required for a non-loopback listener"
	end
	return self.http_server:start(host, self.options.port or self.port)
end

function Server:stop()
	self.http_server:stop()
end

---@return string?
---@return integer?
function Server:getAddress()
	return self.http_server:getAddress()
end

return Server
