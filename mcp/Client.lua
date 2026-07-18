local class = require("class")

local HttpStream = require("web.http.HttpStream")
local Protocol = require("mcp.Protocol")
local json = require("web.json")

---@class mcp.ClientInfo
---@field name string
---@field version string
---@field title string?

---@class mcp.Error
---@field code integer
---@field message string
---@field data any?

---@alias mcp.ClientErrorKind "transport"|"http"|"protocol"|"rpc"

---@class mcp.ClientErrorFields
---@field code integer?
---@field data any?
---@field status integer?
---@field headers web.Headers?
---@field body string?

---@class mcp.ClientError: mcp.ClientErrorFields
---@field kind mcp.ClientErrorKind
---@field message string

---@class mcp.HttpResponse
---@field status integer
---@field headers web.Headers
---@field body string

---@class mcp.ClientOptions
---@field url string
---@field token string?
---@field timeout number?
---@field scheduler web.CosocketScheduler?
---@field protocol_version string?
---@field client_info mcp.ClientInfo?
---@field capabilities table?
---@field request (fun(url: string, body: string, options: web.HttpRequestOptions): mcp.HttpResponse?, string?)?

---@class mcp.Client
---@operator call: mcp.Client
---@field options mcp.ClientOptions
---@field protocol_version string?
---@field server_info mcp.Implementation?
---@field server_capabilities table?
---@field next_id integer
---@field active_streams {[web.HttpStream]: true}
---@field closed boolean
local Client = class()

Client.default_protocol_version = Protocol.latest_version

---@param kind mcp.ClientErrorKind
---@param message string
---@param fields mcp.ClientErrorFields?
---@return mcp.ClientError
local function client_error(kind, message, fields)
	local err = fields or {}
	err.kind = kind
	err.message = message
	return err
end

---@param options mcp.ClientOptions
function Client:new(options)
	assert(type(options.url) == "string", "MCP client URL is required")
	self.options = options
	self.next_id = 1
	self.active_streams = {}
	self.closed = false
end

---@param url string
---@param body string
---@param options web.HttpRequestOptions
---@return mcp.HttpResponse?
---@return mcp.ClientError?
function Client:requestHttp(url, body, options)
	local stream = HttpStream(options)
	self.active_streams[stream] = true

	local function close_stream()
		self.active_streams[stream] = nil
		stream:close()
	end

	local ok, err = stream:connect(url)
	if not ok then
		close_stream()
		return nil, client_error("transport", tostring(err))
	end
	ok, err = stream:sendBody(body)
	if not ok then
		close_stream()
		return nil, client_error("transport", tostring(err))
	end
	local response_body
	response_body, err = stream:receiveBody()
	if not response_body then
		close_stream()
		return nil, client_error("transport", tostring(err))
	end
	local response = assert(stream.res)
	local result = {
		status = response.status,
		headers = response.headers,
		body = response_body,
	}
	close_stream()
	return result
end

---@param message table
---@param initializing boolean?
---@return table?
---@return mcp.ClientError?
function Client:send(message, initializing)
	if self.closed then
		return nil, client_error("protocol", "MCP client is closed")
	end

	local headers = {
		["Content-Type"] = "application/json",
		Accept = "application/json, text/event-stream",
	}
	local token = self.options.token
	if token and token ~= "" then
		headers.Authorization = "Bearer " .. token
	end
	if self.protocol_version and not initializing then
		headers["MCP-Protocol-Version"] = self.protocol_version
	end

	local request_func = self.options.request
	local response, request_err
	local request_options = {
		method = "POST",
		headers = headers,
		scheduler = self.options.scheduler,
		timeout = self.options.timeout,
	}
	if request_func then
		response, request_err = request_func(self.options.url, json.encode(message), request_options)
	else
		response, request_err = self:requestHttp(self.options.url, json.encode(message), request_options)
	end
	if not response then
		if type(request_err) == "table" then
			return nil, request_err
		end
		return nil, client_error("transport", tostring(request_err))
	end
	if response.status == 202 then
		if message.id ~= nil then
			return nil, client_error("protocol", "MCP request received HTTP 202")
		end
		return {}
	end

	local decoded, decode_err = json.decode_safe(response.body)
	if response.status ~= 200 then
		local rpc_err = type(decoded) == "table" and decoded.error or nil
		return nil, client_error("http", rpc_err and rpc_err.message or ("MCP HTTP status " .. response.status), {
			code = rpc_err and rpc_err.code or nil,
			data = rpc_err and rpc_err.data or nil,
			status = response.status,
			headers = response.headers,
			body = response.body,
		})
	end
	if type(decoded) ~= "table" then
		return nil, client_error("protocol", "invalid MCP response: " .. tostring(decode_err), {body = response.body})
	end
	if decoded.jsonrpc ~= "2.0" or decoded.id ~= message.id then
		return nil, client_error("protocol", "invalid MCP JSON-RPC response", {body = response.body})
	end
	if decoded.error then
		return nil, client_error("rpc", decoded.error.message, {
			code = decoded.error.code,
			data = decoded.error.data,
			body = response.body,
		})
	end
	return decoded.result
end

---@param method string
---@param params table?
---@return any?
---@return mcp.ClientError?
function Client:request(method, params)
	if self.closed then
		return nil, client_error("protocol", "MCP client is closed")
	end
	if not self.protocol_version then
		return nil, client_error("protocol", "MCP client is not initialized")
	end
	local id = self.next_id
	self.next_id = id + 1
	local message = {
		jsonrpc = "2.0",
		id = id,
		method = method,
		params = params,
	}
	return self:send(message)
end

---@param method string
---@param params table?
---@return true?
---@return mcp.ClientError?
function Client:notify(method, params)
	local _, err = self:send({
		jsonrpc = "2.0",
		method = method,
		params = params,
	})
	if err then
		return nil, err
	end
	return true
end

---@return table?
---@return mcp.ClientError?
function Client:initialize()
	if self.protocol_version then
		return nil, client_error("protocol", "MCP client is already initialized")
	end
	local requested_protocol = self.options.protocol_version or self.default_protocol_version
	local id = self.next_id
	self.next_id = id + 1
	local result, err = self:send({
		jsonrpc = "2.0",
		id = id,
		method = "initialize",
		params = {
			protocolVersion = requested_protocol,
			capabilities = self.options.capabilities or {},
			clientInfo = self.options.client_info or {name = "aqua-mcp", version = "dev"},
		},
	}, true)
	if not result then
		return nil, err
	end
	if type(result.protocolVersion) ~= "string"
		or type(result.capabilities) ~= "table"
		or type(result.serverInfo) ~= "table"
	then
		return nil, client_error("protocol", "invalid MCP initialize result")
	end
	if not Protocol.isSupported(result.protocolVersion) then
		return nil, client_error("protocol", "unsupported MCP protocol version: " .. result.protocolVersion)
	end
	self.protocol_version = result.protocolVersion
	self.server_capabilities = result.capabilities
	self.server_info = result.serverInfo
	local ok, notify_err = self:notify("notifications/initialized")
	if not ok then
		self.protocol_version = nil
		return nil, notify_err
	end
	return result
end

---@param cursor string?
---@return table?
---@return mcp.ClientError?
function Client:listTools(cursor)
	local params
	if cursor then
		params = {cursor = cursor}
	end
	return self:request("tools/list", params)
end

---@param name string
---@param arguments {[string]: any}?
---@return table?
---@return mcp.ClientError?
function Client:callTool(name, arguments)
	return self:request("tools/call", {
		name = name,
		arguments = arguments or {},
	})
end

---@return table?
---@return mcp.ClientError?
function Client:ping()
	return self:request("ping")
end

---@param err string?
---@return integer canceled
function Client:cancel(err)
	---@type web.HttpStream[]
	local streams = {}
	for stream in pairs(self.active_streams) do
		table.insert(streams, stream)
	end
	self.active_streams = {}
	for _, stream in ipairs(streams) do
		stream:cancel(err or "MCP request canceled")
	end
	return #streams
end

function Client:close()
	if self.closed then
		return
	end
	self.closed = true
	self:cancel("MCP client closed")
	self.protocol_version = nil
	self.server_info = nil
	self.server_capabilities = nil
end

return Client
