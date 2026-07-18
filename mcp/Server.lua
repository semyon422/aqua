local class = require("class")
local socket = require("socket")
local socket_url = require("socket.url")

local HttpServer = require("web.http.Server")
local JsonSchema = require("mcp.JsonSchema")
local Protocol = require("mcp.Protocol")
local RequestContext = require("mcp.RequestContext")
local ToolResult = require("mcp.ToolResult")
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
---@field execute fun(self: mcp.Tool, args: {[string]: any}, context: mcp.RequestContext): string|mcp.ToolResult, boolean?, table?

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
---@field rate_limit integer?
---@field rate_limit_window number?
---@field get_time (fun(): number)?
---@field session_id_generator (fun(): string)?
---@field on_error (fun(err: string))?
---@field server_info mcp.Implementation?

---@class mcp.Session
---@field id string
---@field active_requests {[string|number]: mcp.RequestContext}

---@class mcp.Server
---@operator call: mcp.Server
---@field tools mcp.Tool[]
---@field tools_by_name {[string]: mcp.Tool}
---@field options mcp.ServerOptions
---@field http_server web.HttpServer
---@field rate_limit integer?
---@field rate_limits {[string]: mcp.RateLimitState}
---@field sessions {[string]: mcp.Session}
local Server = class()

---@class mcp.RateLimitState
---@field started_at number
---@field count integer

---@param host string
---@return boolean
local function is_loopback(host)
	return host == "localhost" or host == "::1" or host:match("^127%.") ~= nil
end

Server.protocol_version = Protocol.latest_version
Server.supported_versions = Protocol.supported_versions
Server.host = "127.0.0.1"
Server.port = 38679
Server.path = "/mcp"
Server.max_body_size = 1024 * 1024

---@param scheduler web.CosocketScheduler
---@param tools mcp.Tool[]
---@param options mcp.ServerOptions?
function Server:new(scheduler, tools, options)
	self.options = options or {}
	if self.options.rate_limit ~= nil then
		assert(self.options.rate_limit >= 0 and self.options.rate_limit % 1 == 0, "MCP rate_limit must be a non-negative integer")
	end
	if self.options.rate_limit_window ~= nil then
		assert(self.options.rate_limit_window > 0, "MCP rate_limit_window must be positive")
	end
	self.rate_limits = {}
	self.sessions = {}
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

---@param err string
function Server:reportError(err)
	local on_error = self.options.on_error
	if on_error then
		on_error(err)
	else
		print("MCP server error: " .. err)
	end
end

---@return mcp.Session?
---@return string?
function Server:createSession()
	local generator = self.options.session_id_generator
	if not generator then
		return nil, "MCP sessions are disabled"
	end
	local id = generator()
	if type(id) ~= "string" or id == "" then
		return nil, "MCP session_id_generator must return a non-empty string"
	elseif self.sessions[id] then
		return nil, "duplicate MCP session ID"
	end
	local session = {id = id, active_requests = {}}
	self.sessions[id] = session
	return session
end

---@param session mcp.Session
---@param reason string?
function Server:closeSession(session, reason)
	for _, context in pairs(session.active_requests) do
		local _, err = context:cancel(reason or "MCP session closed")
		if err then
			self:reportError(err)
		end
	end
	self.sessions[session.id] = nil
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

---@param text string
---@return mcp.CallToolResult
local function tool_error(text)
	return {
		content = {{type = "text", text = text}},
		isError = true,
	}
end

---@param req web.Request
---@return boolean
function Server:isAuthorized(req)
	local token = self.options.token
	if not token or token == "" then
		return true
	end
	local authorization = req.headers:getTable("Authorization")
	return #authorization == 1 and authorization[1] == "Bearer " .. token
end

---@param req web.Request
---@return boolean
function Server:isOriginAllowed(req)
	-- Browser origins are rejected by default. Native MCP clients omit Origin,
	-- which prevents a remote web page from reaching this loopback service.
	return req.headers:get("Origin") == nil
end

---@param message table
---@param session mcp.Session?
---@return table?
function Server:dispatch(message, session)
	local id = message.id
	local method = message.method
	if type(method) ~= "string" or message.jsonrpc ~= "2.0" then
		return rpc_error(id, -32600, "Invalid Request")
	end
	if id ~= nil and type(id) ~= "string" and type(id) ~= "number" then
		return rpc_error(nil, -32600, "Invalid Request")
	end

	if method == "notifications/initialized" then
		return
	elseif method == "notifications/cancelled" then
		local params = message.params
		if session and type(params) == "table" then
			local request_id = params.requestId
			local reason = params.reason
			if (type(request_id) == "string" or type(request_id) == "number") and (reason == nil or type(reason) == "string") then
				local context = session.active_requests[request_id]
				if context then
					local _, cancel_err = context:cancel(reason)
					if cancel_err then
						self:reportError(cancel_err)
					end
				end
			end
		end
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

		if session and session.active_requests[id] then
			return rpc_error(id, -32600, "Request ID is already active")
		end
		local context = RequestContext(id)
		if session then
			session.active_requests[id] = context
		end
		local ok, output, is_error, structured_content = xpcall(tool.execute, debug.traceback, tool, arguments, context)
		if session then
			session.active_requests[id] = nil
		end
		if not ok then
			return rpc_result(id, tool_error(tostring(output)))
		elseif context.canceled then
			return rpc_result(id, tool_error(assert(context.cancel_reason)))
		end
		local result, result_err = ToolResult.normalize(output, is_error, structured_content)
		if not result then
			return rpc_result(id, tool_error(assert(result_err)))
		end
		if tool.output_schema then
			if result.structuredContent == nil then
				return rpc_result(id, tool_error("tool did not return required structured content"))
			end
			local valid_output, output_err = JsonSchema.validate(tool.output_schema, result.structuredContent)
			if not valid_output then
				return rpc_result(id, tool_error("invalid structured tool output: " .. output_err))
			end
		end
		return rpc_result(id, result)
	end

	return rpc_error(id, -32601, "Method not found: " .. method)
end

---@param messages table[]
---@param session mcp.Session?
---@return table[]|table?
function Server:dispatchBatch(messages, session)
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
			response = self:dispatch(message, session)
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

---@param ip string
---@return boolean
---@return integer? retry_after
function Server:checkRateLimit(ip)
	local limit = self.rate_limit
	if not limit then
		return true
	end
	local window = self.options.rate_limit_window or 60
	local get_time = self.options.get_time or socket.gettime
	local now = get_time()
	local state = self.rate_limits[ip]
	if not state or now - state.started_at >= window then
		state = {started_at = now, count = 0}
		self.rate_limits[ip] = state
	end
	if state.count >= limit then
		return false, math.max(math.ceil(window - (now - state.started_at)), 1)
	end
	state.count = state.count + 1
	return true
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
	local within_limit, retry_after = self:checkRateLimit(ip)
	if not within_limit then
		res.headers:set("Retry-After", assert(retry_after))
		send_response(res, 429, json.encode(rpc_error(nil, -32000, "MCP request rate limit exceeded")), "application/json")
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
	if req.method == "DELETE" and self.options.session_id_generator then
		local requested_protocol = req.headers:get("MCP-Protocol-Version")
		if requested_protocol and not self.supported_versions[requested_protocol] then
			send_response(res, 400, json.encode(rpc_error(nil, -32000, "Unsupported MCP protocol version: " .. requested_protocol)), "application/json")
			return
		end
		local session_headers = req.headers:getTable("Mcp-Session-Id")
		if #session_headers ~= 1 then
			send_response(res, 400, json.encode(rpc_error(nil, -32000, "Mcp-Session-Id header is required")), "application/json")
			return
		end
		local session = self.sessions[session_headers[1]]
		if not session then
			send_response(res, 404, json.encode(rpc_error(nil, -32001, "Session not found")), "application/json")
			return
		end
		self:closeSession(session)
		send_response(res, 200, "{}", "application/json")
		return
	elseif req.method == "GET" or req.method == "DELETE" then
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
	local content_length_header = req.headers:get("Content-Length")
	local content_length = tonumber(content_length_header)
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
	local contains_initialize = is_batch and has_initialize(message) or message.method == "initialize"
	local initializing = not is_batch and message.method == "initialize"
	local requested_protocol = req.headers:get("MCP-Protocol-Version")
	if not contains_initialize and requested_protocol and not self.supported_versions[requested_protocol] then
		send_response(res, 400, json.encode(rpc_error(nil, -32000, "Unsupported MCP protocol version: " .. requested_protocol)), "application/json")
		return
	end

	local session
	if self.options.session_id_generator and initializing and #req.headers:getTable("Mcp-Session-Id") > 0 then
		send_response(res, 400, json.encode(rpc_error(nil, -32000, "Initialization must not include Mcp-Session-Id")), "application/json")
		return
	elseif self.options.session_id_generator and not contains_initialize then
		local session_headers = req.headers:getTable("Mcp-Session-Id")
		if #session_headers ~= 1 then
			send_response(res, 400, json.encode(rpc_error(nil, -32000, "Mcp-Session-Id header is required")), "application/json")
			return
		end
		session = self.sessions[session_headers[1]]
		if not session then
			send_response(res, 404, json.encode(rpc_error(nil, -32001, "Session not found")), "application/json")
			return
		end
	end

	local response
	if is_batch then
		response = self:dispatchBatch(message, session)
	else
		response = self:dispatch(message, session)
	end
	if not response then
		send_response(res, 202)
		return
	end
	local response_protocol = requested_protocol or self.protocol_version
	if initializing then
		response_protocol = response.result and response.result.protocolVersion or self.protocol_version
		if response.result and self.options.session_id_generator then
			local session_err
			session, session_err = self:createSession()
			if not session then
				send_response(res, 500, json.encode(rpc_error(nil, -32603, assert(session_err))), "application/json")
				return
			end
			res.headers:set("Mcp-Session-Id", session.id)
		end
	end
	res.headers:set("MCP-Protocol-Version", response_protocol)
	res.headers:set("Cache-Control", "no-store")
	local sent = send_response(res, 200, json.encode(response), "application/json")
	if not sent and initializing and session then
		self:closeSession(session, "MCP initialization response failed")
	end
end

---@return true?
---@return string?
function Server:start()
	local host = self.options.host or self.host
	local token = self.options.token
	if not is_loopback(host) and (not token or token == "") then
		return nil, "MCP authentication token is required for a non-loopback listener"
	end
	self.rate_limits = {}
	self.sessions = {}
	local configured_rate_limit = self.options.rate_limit
	if configured_rate_limit == nil and not is_loopback(host) then
		self.rate_limit = 120
	elseif configured_rate_limit and configured_rate_limit > 0 then
		self.rate_limit = configured_rate_limit
	else
		self.rate_limit = nil
	end
	return self.http_server:start(host, self.options.port or self.port)
end

function Server:stop()
	self.http_server:stop()
	local sessions = self.sessions
	self.sessions = {}
	for _, session in pairs(sessions) do
		self:closeSession(session, "MCP server stopped")
	end
	self.rate_limits = {}
end

---@return string?
---@return integer?
function Server:getAddress()
	return self.http_server:getAddress()
end

return Server
