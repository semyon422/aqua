local class = require("class")
local json = require("web.json")
local random = require("web.random")
local socket = require("socket")
local HttpServer = require("web.http.Server")

---@class aqua.openai.ProxyUser
---@field name string
---@field access_token string

---@class aqua.openai.ProxyClient
---@field completeStream fun(self: aqua.openai.ProxyClient, messages: aqua.openai.Message[], tools: aqua.openai.ToolSchema[]?, on_text_delta: (fun(content: string))?): aqua.openai.Message?, string?

---@class aqua.openai.ProxyServerOptions
---@field scheduler web.CosocketScheduler
---@field users aqua.openai.ProxyUser[]
---@field models string[]
---@field create_client fun(model: string): aqua.openai.ProxyClient
---@field logger (fun(line: string))?
---@field max_body_size integer?
---@field client_timeout number?

---@class aqua.openai.ProxyServer
---@operator call: aqua.openai.ProxyServer
---@field users_by_token {[string]: string}
---@field models string[]
---@field models_set {[string]: boolean}
---@field create_client fun(model: string): aqua.openai.ProxyClient
---@field logger fun(line: string)
---@field max_body_size integer
---@field http_server web.HttpServer
local ProxyServer = class()

ProxyServer.max_body_size = 1024 * 1024

---@param options aqua.openai.ProxyServerOptions
function ProxyServer:new(options)
	assert(type(options.users) == "table" and #options.users > 0, "at least one proxy user is required")
	assert(type(options.models) == "table" and #options.models > 0, "at least one proxy model is required")
	self.users_by_token = {}
	for _, user in ipairs(options.users) do
		assert(type(user.name) == "string" and user.name ~= "", "proxy user name is required")
		assert(type(user.access_token) == "string" and user.access_token ~= "", "proxy user access_token is required")
		assert(not self.users_by_token[user.access_token], "duplicate proxy user access_token")
		self.users_by_token[user.access_token] = user.name
	end
	self.models = options.models
	self.models_set = {}
	for _, model in ipairs(options.models) do
		assert(type(model) == "string" and model ~= "", "proxy model must be a non-empty string")
		assert(not self.models_set[model], "duplicate proxy model: " .. model)
		self.models_set[model] = true
	end
	self.create_client = assert(options.create_client, "create_client is required")
	self.logger = options.logger or print
	self.max_body_size = options.max_body_size or self.max_body_size
	assert(self.max_body_size >= 1, "max_body_size must be positive")
	self.http_server = HttpServer(options.scheduler, function(req, res, ip)
		self:handle(req, res, ip)
	end, {
		client_timeout = options.client_timeout or 30,
		max_header_size = 16384,
		max_header_count = 64,
	})
end

---@param req web.Request
---@return string?
function ProxyServer:authenticate(req)
	local authorization = req.headers:get("Authorization")
	local token = authorization and authorization:match("^Bearer (.+)$")
	if not token then return end
	return self.users_by_token[token]
end

---@param res web.Response
---@param status integer
---@param message string
---@param error_type string
---@param code string
local function sendError(res, status, message, error_type, code)
	local body = json.encode({
		error = {
			message = message,
			type = error_type,
			code = code,
		},
	})
	res.status = status
	res.headers:set("Content-Type", "application/json")
	if status == 401 then res.headers:set("WWW-Authenticate", "Bearer") end
	res:set_length(#body)
	res:send(body)
end

---@param res web.Response
---@param body table
local function sendJson(res, body)
	local encoded = json.encode(body)
	res.status = 200
	res.headers:set("Content-Type", "application/json")
	res:set_length(#encoded)
	res:send(encoded)
end

---@param model string
---@param message aqua.openai.Message
---@param completion_id string
---@param created integer
---@return table
local function createCompletion(model, message, completion_id, created)
	local output_message = {
		role = "assistant",
		content = message.content or "",
	}
	if message.tool_calls then output_message.tool_calls = message.tool_calls end
	return {
		id = completion_id,
		object = "chat.completion",
		created = created,
		model = model,
		choices = {{
			index = 0,
			message = output_message,
			finish_reason = message.tool_calls and "tool_calls" or "stop",
		}},
	}
end

---@param res web.Response
---@param event table|string
---@return boolean
local function sendEvent(res, event)
	local data = type(event) == "string" and event or json.encode(event)
	local sent = res:send("data: " .. data .. "\n\n")
	return sent ~= nil
end

---@param res web.Response
local function startEventStream(res)
	if res.headers_sent then return end
	res.status = 200
	res.headers:set("Content-Type", "text/event-stream")
	res.headers:set("Cache-Control", "no-cache")
	res:set_chunked_encoding()
	res:send_headers()
end

---@param res web.Response
---@param model string
---@param completion_id string
---@param created integer
---@param delta table
---@param finish_reason string?
local function sendChunk(res, model, completion_id, created, delta, finish_reason)
	sendEvent(res, {
		id = completion_id,
		object = "chat.completion.chunk",
		created = created,
		model = model,
		choices = {{index = 0, delta = delta, finish_reason = finish_reason}},
	})
end

---@param messages any
---@return boolean
local function validateMessages(messages)
	if not json.isArray(messages) or #messages == 0 then return false end
	for _, message in ipairs(messages) do
		if not json.isObject(message) then return false end
		local role = message.role
		if role ~= "system" and role ~= "user" and role ~= "assistant" and role ~= "tool" then
			return false
		end
		if role == "system" or role == "user" or role == "tool" then
			if type(message.content) ~= "string" then return false end
		elseif message.content ~= nil and message.content ~= json.null and type(message.content) ~= "string" then
			return false
		end
		if role == "tool" and type(message.tool_call_id) ~= "string" then return false end
		if message.tool_calls ~= nil and not json.isArray(message.tool_calls) then return false end
		for _, tool_call in ipairs(message.tool_calls or {}) do
			local schema = type(tool_call) == "table" and tool_call["function"] or nil
			if type(tool_call.id) ~= "string" or type(schema) ~= "table"
				or type(schema.name) ~= "string" or type(schema.arguments) ~= "string"
			then
				return false
			end
		end
		if role == "assistant" and type(message.content) ~= "string" and not (message.tool_calls and message.tool_calls[1]) then
			return false
		end
	end
	return true
end

---@param tools any
---@return boolean
local function validateTools(tools)
	if tools == nil then return true end
	if not json.isArray(tools) then return false end
	for _, tool in ipairs(tools) do
		local schema = type(tool) == "table" and tool["function"] or nil
		if tool.type ~= "function" or type(schema) ~= "table"
			or type(schema.name) ~= "string" or schema.name == ""
			or type(schema.parameters) ~= "table"
		then
			return false
		end
	end
	return true
end

---@param res web.Response
---@param request table
---@return integer status
function ProxyServer:complete(res, request)
	if type(request.model) ~= "string" or not self.models_set[request.model] then
		sendError(res, 400, "model is not available", "invalid_request_error", "model_not_found")
		return 400
	elseif not validateMessages(request.messages) then
		sendError(res, 400, "messages must be an array", "invalid_request_error", "invalid_messages")
		return 400
	elseif not validateTools(request.tools) then
		sendError(res, 400, "tools must be an array", "invalid_request_error", "invalid_tools")
		return 400
	elseif request.stream ~= nil and type(request.stream) ~= "boolean" then
		sendError(res, 400, "stream must be a boolean", "invalid_request_error", "invalid_stream")
		return 400
	end

	local client = self.create_client(request.model)
	local completion_id = "chatcmpl-" .. random.hex(16)
	local created = os.time()
	if not request.stream then
		local message = client:completeStream(request.messages, request.tools)
		if not message then
			sendError(res, 502, "upstream request failed", "upstream_error", "upstream_error")
			return 502
		end
		sendJson(res, createCompletion(request.model, message, completion_id, created))
		return 200
	end

	local started = false
	local function ensureStarted()
		if started then return end
		started = true
		startEventStream(res)
		sendChunk(res, request.model, completion_id, created, {role = "assistant"})
	end
	local message = client:completeStream(request.messages, request.tools, function(content)
		ensureStarted()
		sendChunk(res, request.model, completion_id, created, {content = content})
	end)
	if not message then
		if not started then
			sendError(res, 502, "upstream request failed", "upstream_error", "upstream_error")
			return 502
		end
		sendEvent(res, {error = {message = "upstream request failed", type = "upstream_error", code = "upstream_error"}})
		sendEvent(res, "[DONE]")
		res:send("")
		return 502
	end
	ensureStarted()
	if message.tool_calls then
		local tool_calls = {}
		for index, tool_call in ipairs(message.tool_calls) do
			tool_calls[index] = {
				index = index - 1,
				id = tool_call.id,
				type = "function",
				["function"] = tool_call["function"],
			}
		end
		sendChunk(res, request.model, completion_id, created, {tool_calls = tool_calls})
	end
	sendChunk(res, request.model, completion_id, created, {}, message.tool_calls and "tool_calls" or "stop")
	sendEvent(res, "[DONE]")
	res:send("")
	return 200
end

---@param req web.Request
---@param res web.Response
---@param ip string
function ProxyServer:handle(req, res, ip)
	local started_at = socket.gettime()
	local user = self:authenticate(req)
	local status
	local path = req.uri:match("^[^?]+") or req.uri
	if not user then
		sendError(res, 401, "invalid access token", "authentication_error", "invalid_api_key")
		status = 401
	elseif req.method == "GET" and path == "/v1/models" then
		local models = {}
		for _, model in ipairs(self.models) do
			table.insert(models, {id = model, object = "model", owned_by = "openai-subscription"})
		end
		sendJson(res, {object = "list", data = models})
		status = 200
	elseif req.method == "POST" and path == "/v1/chat/completions" then
		local content_length = tonumber(req.headers:get("Content-Length"))
		if not content_length then
			sendError(res, 411, "Content-Length is required", "invalid_request_error", "length_required")
			status = 411
		elseif content_length > self.max_body_size then
			sendError(res, 413, "request body is too large", "invalid_request_error", "request_too_large")
			status = 413
		else
			local body, receive_err = req:receive("*a")
			local request, decode_err = body and json.decode_safe(body) or nil
			if type(request) ~= "table" then
				sendError(res, 400, "invalid JSON body: " .. tostring(decode_err or receive_err), "invalid_request_error", "invalid_json")
				status = 400
			else
				status = self:complete(res, request)
			end
		end
	else
		sendError(res, 404, "route not found", "invalid_request_error", "not_found")
		status = 404
	end
	self.logger(("user=%s ip=%s method=%s path=%s status=%d duration=%.3fs")
		:format(user or "-", ip, req.method, path, status, socket.gettime() - started_at))
end

---@param host string
---@param port integer
---@return true?
---@return string?
function ProxyServer:start(host, port)
	return self.http_server:start(host, port)
end

function ProxyServer:stop()
	self.http_server:stop()
end

---@return string?
---@return integer?
function ProxyServer:getAddress()
	return self.http_server:getAddress()
end

return ProxyServer
