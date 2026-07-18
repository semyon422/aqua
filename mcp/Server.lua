local class = require("class")
local socket_url = require("socket.url")

local HttpServer = require("web.http.Server")
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
---@field annotations mcp.ToolAnnotations?
---@field execute fun(self: mcp.Tool, args: {[string]: any}): string, boolean?

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
		assert(type(tool.execute) == "function", "MCP tool execute must be a function")
		assert(not self.tools_by_name[tool.name], "duplicate MCP tool: " .. tool.name)
		self.tools_by_name[tool.name] = tool
	end
	self.http_server = HttpServer(scheduler, function(req, res, ip, port)
		self:handleHttp(req, res, ip, port)
	end, {
		client_timeout = self.options.client_timeout or 10,
		on_error = self.options.on_error,
	})
end

---@param res web.Response
---@param status integer
---@param body string?
---@param content_type string?
local function send_response(res, status, body, content_type)
	body = body or ""
	res.status = status
	res:set_length(#body)
	if content_type then
		res.headers:set("Content-Type", content_type)
	end
	assert(res:send(body))
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

	if method == "notifications/initialized" or method == "notifications/cancelled" then
		return
	end
	if id == nil then
		return
	end

	if method == "initialize" then
		local params = message.params
		local requested = type(params) == "table" and params.protocolVersion or nil
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
		return rpc_result(id, {})
	elseif method == "tools/list" then
		---@type table[]
		local tools = {}
		for _, tool in ipairs(self.tools) do
			table.insert(tools, {
				name = tool.name,
				description = tool.description,
				inputSchema = tool.input_schema,
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

		local ok, output, is_error = xpcall(tool.execute, debug.traceback, tool, arguments)
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
		return rpc_result(id, {
			content = {{type = "text", text = output}},
			isError = is_error == true,
		})
	end

	return rpc_error(id, -32601, "Method not found: " .. method)
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

	local response = self:dispatch(message)
	if not response then
		send_response(res, 202)
		return
	end
	res.headers:set("MCP-Protocol-Version", self.protocol_version)
	res.headers:set("Cache-Control", "no-store")
	send_response(res, 200, json.encode(response), "application/json")
end

---@return true?
---@return string?
function Server:start()
	return self.http_server:start(self.options.host or self.host, self.options.port or self.port)
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
