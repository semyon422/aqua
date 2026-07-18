local class = require("class")

local http_util = require("web.http.util")
local json = require("web.json")

---@class mcp.ClientInfo
---@field name string
---@field version string
---@field title string?

---@class mcp.Error
---@field code integer
---@field message string
---@field data any?

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
---@field closed boolean
local Client = class()

Client.default_protocol_version = "2025-11-25"

---@param options mcp.ClientOptions
function Client:new(options)
	assert(type(options.url) == "string", "MCP client URL is required")
	self.options = options
	self.next_id = 1
	self.closed = false
end

---@param message table
---@param initializing boolean?
---@return table?
---@return string|mcp.Error?
function Client:send(message, initializing)
	if self.closed then
		return nil, "MCP client is closed"
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

	local request_func = self.options.request or http_util.request
	local response, request_err = request_func(self.options.url, json.encode(message), {
		method = "POST",
		headers = headers,
		scheduler = self.options.scheduler,
		timeout = self.options.timeout,
	})
	if not response then
		return nil, request_err
	end
	if response.status == 202 then
		return {}
	end

	local decoded, decode_err = json.decode_safe(response.body)
	if type(decoded) ~= "table" then
		return nil, "invalid MCP response: " .. tostring(decode_err)
	end
	if response.status ~= 200 then
		return nil, decoded.error or ("MCP HTTP status " .. response.status)
	end
	if decoded.jsonrpc ~= "2.0" or decoded.id ~= message.id then
		return nil, "invalid MCP JSON-RPC response"
	end
	if decoded.error then
		return nil, decoded.error
	end
	return decoded.result
end

---@param method string
---@param params table?
---@return any?
---@return string|mcp.Error?
function Client:request(method, params)
	if self.closed then
		return nil, "MCP client is closed"
	end
	if not self.protocol_version then
		return nil, "MCP client is not initialized"
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
---@return string|mcp.Error?
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
---@return string|mcp.Error?
function Client:initialize()
	if self.protocol_version then
		return nil, "MCP client is already initialized"
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
		return nil, "invalid MCP initialize result"
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
---@return string|mcp.Error?
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
---@return string|mcp.Error?
function Client:callTool(name, arguments)
	return self:request("tools/call", {
		name = name,
		arguments = arguments or {},
	})
end

---@return table?
---@return string|mcp.Error?
function Client:ping()
	return self:request("ping")
end

function Client:close()
	self.closed = true
	self.protocol_version = nil
	self.server_info = nil
	self.server_capabilities = nil
end

return Client
