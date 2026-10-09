local class = require("class")
local digest = require("digest")
local json = require("web.json")
local random = require("web.random")
---@type {gettime: fun(): number}
local socket = require("socket")
local HttpServer = require("web.http.Server")
local UsagePage = require("ai.openai.UsagePage")
local ChatCompat = require("ai.openai.ChatCompat")

---@class openai.ProxyUser
---@field name string
---@field access_token string

---@class openai.ProxyClient
---@field completeStream fun(self: openai.ProxyClient, messages: openai.Message[], tools: openai.ToolSchema[]?, on_text_delta: (fun(content: string): boolean?)?, on_reasoning_delta: (fun(content: string): boolean?)?, on_tool_call_delta: (fun(delta: openai.ToolCallDelta): boolean?)?): openai.Message?, string?, openai.ProviderError?
---@field createResponse fun(self: openai.ProxyClient, request: table, on_event: (fun(event: table): boolean?)?): table?, string?, openai.ProviderError?

---@class openai.UntrustedObject
---@field [any] any

---@class openai.PromptCacheBreakpoint: openai.UntrustedObject
---@field mode any?

---@class openai.ImagePart: openai.UntrustedObject
---@field url any?
---@field detail any?

---@class openai.AudioPart: openai.UntrustedObject
---@field data any?
---@field format any?

---@class openai.FilePart: openai.UntrustedObject
---@field file_data any?
---@field file_id any?
---@field filename any?

---@class openai.ContentPart: openai.UntrustedObject
---@field type any?
---@field text any?
---@field refusal any?
---@field prompt_cache_breakpoint openai.PromptCacheBreakpoint?
---@field image_url openai.ImagePart?
---@field input_audio openai.AudioPart?
---@field file openai.FilePart?

---@class openai.UntrustedFunctionCall: openai.UntrustedObject
---@field name any?
---@field arguments any?

---@class openai.UntrustedMessage: openai.UntrustedObject
---@field role any?
---@field content any?
---@field function_call openai.UntrustedFunctionCall?
---@field tool_calls any?
---@field name any?
---@field tool_call_id any?

---@class openai.ProxyRequestOptions
---@field prompt_cache_key string?
---@field prompt_cache_options openai.PromptCacheOptions?
---@field session_id string?
---@field tool_choice "none"|"auto"|"required"|openai.ResponsesFunctionToolChoice?
---@field parallel_tool_calls boolean
---@field verbosity "low"|"medium"|"high"?
---@field text_format openai.ResponsesTextFormat?

---@class openai.ProxyServerOptions
---@field scheduler web.CosocketScheduler
---@field users openai.ProxyUser[]
---@field models string[]
---@field model_redirects {[string]: string}?
---@field create_client fun(model: string, reasoning_effort: openai.ReasoningEffort?, request_options: openai.ProxyRequestOptions): openai.ProxyClient
---@field usage_repo openai.UsageRepo?
---@field fetch_usage (fun(): table?, string?, openai.ProviderError?)?
---@field logger (fun(line: string))?
---@field max_body_size integer?
---@field client_timeout number?
---@field max_clients integer?
---@field max_concurrent_requests_per_user integer?
---@field max_requests_per_minute integer?
---@field get_time (fun(): number)?

---@class openai.ProxyServer
---@operator call: openai.ProxyServer
---@field users_by_token {[string]: string}
---@field models string[]
---@field models_set {[string]: boolean}
---@field model_redirects {[string]: string}
---@field create_client fun(model: string, reasoning_effort: openai.ReasoningEffort?, request_options: openai.ProxyRequestOptions): openai.ProxyClient
---@field usage_repo openai.UsageRepo?
---@field fetch_usage fun(): table?, string?, openai.ProviderError?
---@field logger fun(line: string)
---@field max_body_size integer
---@field max_concurrent_requests_per_user integer
---@field max_requests_per_minute integer
---@field active_requests {[string]: integer}
---@field request_windows {[string]: {started_at: number, count: integer}}
---@field get_time fun(): number
---@field http_server web.HttpServer
local ProxyServer = class()

ProxyServer.max_body_size = 16 * 1024 * 1024
ProxyServer.max_clients = 64
ProxyServer.max_concurrent_requests_per_user = 4
ProxyServer.max_requests_per_minute = 120

---@param options openai.ProxyServerOptions
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
	self.model_redirects = {}
	for requested_model, upstream_model in pairs(options.model_redirects or {}) do
		assert(type(requested_model) == "string" and self.models_set[requested_model],
			"model redirect source is not configured: " .. tostring(requested_model))
		assert(type(upstream_model) == "string" and upstream_model ~= "",
			"model redirect target must be a non-empty string")
		self.model_redirects[requested_model] = upstream_model
	end
	self.fetch_usage = options.fetch_usage or function() return nil, "usage is not configured" end
	self.usage_repo = options.usage_repo
	self.logger = options.logger or print
	self.max_body_size = options.max_body_size or self.max_body_size
	self.max_concurrent_requests_per_user = options.max_concurrent_requests_per_user or self.max_concurrent_requests_per_user
	self.max_requests_per_minute = options.max_requests_per_minute or self.max_requests_per_minute
	self.active_requests = {}
	self.request_windows = {}
	self.get_time = options.get_time or socket.gettime
	local max_clients = options.max_clients or self.max_clients
	assert(self.max_body_size >= 1, "max_body_size must be positive")
	assert(max_clients >= 1, "max_clients must be positive")
	assert(self.max_concurrent_requests_per_user >= 1, "max_concurrent_requests_per_user must be positive")
	assert(self.max_requests_per_minute >= 1, "max_requests_per_minute must be positive")
	self.http_server = HttpServer(options.scheduler, function(req, res, ip)
		self:handle(req, res, ip)
	end, {
		client_timeout = options.client_timeout or 30,
		max_clients = max_clients,
		max_header_size = 16384,
		max_header_count = 64,
	})
end

---@param req web.Request
---@return string?
---@return string?
function ProxyServer:authenticate(req)
	local authorization = req.headers:get("Authorization")
	local token = authorization and authorization:match("^Bearer (.+)$")
	if not token then return end
	return self.users_by_token[token], token
end

local session_affinity_headers = {"x-session-affinity", "session_id", "x-client-request-id"}

---@param prompt_cache_key string?
---@return string?
local function getPromptCacheSessionId(prompt_cache_key)
	if not prompt_cache_key then return end
	return digest.hash("sha256", prompt_cache_key, true)
end

---@param req web.Request
---@return string?
---@return string?
---@return string? source
local function getSessionAffinity(req)
	for _, name in ipairs(session_affinity_headers) do
		local values = req.headers:getTable(name)
		if #values > 1 then return nil, "multiple " .. name .. " headers are not allowed" end
		local value = values[1]
		if value then
			if #value < 1 or #value > 128 or not value:match("^[%w._:%-]+$") then
				return nil, name .. " must contain 1 to 128 letters, digits, or ._:-"
			end
			return value, nil, name
		end
	end
end

---@param res web.Response
---@param status integer
---@param message string
---@param error_type string
---@param code string
---@param request_id string?
local function sendError(res, status, message, error_type, code, request_id)
	local error_body = {
		message = message,
		type = error_type,
		code = code,
		request_id = request_id,
	}
	local body = json.encode({
		error = error_body,
	})
	res.status = status
	res.headers:set("Content-Type", "application/json")
	if request_id then res.headers:set("x-request-id", request_id) end
	if status == 401 then res.headers:set("WWW-Authenticate", "Bearer") end
	res:set_length(#body)
	res:send(body)
end

---@param res web.Response
---@param provider_error openai.ProviderError
---@return integer status
local function sendProviderError(res, provider_error)
	local status = provider_error.status
	if status < 400 or status > 599 then status = 502 end
	sendError(res, status, provider_error.message, provider_error.type, provider_error.code, provider_error.request_id)
	return status
end

---@param res web.Response
---@param body table
local function sendJson(res, body)
	local encoded = json.encode(body)
	res.status = 200
	res.headers:set("Content-Type", "application/json")
	res.headers:set("Cache-Control", "no-store")
	res:set_length(#encoded)
	res:send(encoded)
end

---@param res web.Response
local function sendUsagePage(res)
	local body = UsagePage.render()
	res.status = 200
	res.headers:set("Content-Type", "text/html; charset=utf-8")
	res.headers:set("Cache-Control", "no-store")
	res.headers:set("X-Content-Type-Options", "nosniff")
	res.headers:set("Content-Security-Policy", "default-src 'none'; style-src 'unsafe-inline'; script-src 'unsafe-inline'; connect-src 'self'")
	res.headers:set("Referrer-Policy", "no-referrer")
	res:set_length(#body)
	res:send(body)
end

---@param value any
---@return string
local function sanitizeLogValue(value)
	local sanitized = string.gsub(tostring(value), "[%c\127]", "?")
	return sanitized
end

---@param req web.Request
---@param request {[string]: any}?
---@return string source
---@return string session_hash
local function getLogSession(req, request)
	local session_id, _, source = getSessionAffinity(req)
	if not session_id and request and type(request.prompt_cache_key) == "string"
		and request.prompt_cache_key ~= "" and #request.prompt_cache_key <= 64
	then
		session_id = getPromptCacheSessionId(request.prompt_cache_key)
		source = "prompt_cache_key"
	end
	if not session_id then return "-", "-" end
	return assert(source), "sha256:" .. digest.hash("sha256", session_id, true):sub(1, 16)
end

---@param result {[string]: any}?
---@return string input_tokens
---@return string cached_tokens
---@return string cache_hit
---@return string cache_pct
local function getLogCache(result)
	local usage = result and type(result.usage) == "table" and result.usage or nil
	local input = usage and usage.input_tokens or nil
	if type(input) ~= "number" or input < 0 or input % 1 ~= 0 then return "-", "-", "-", "-" end
	local details = type(usage.input_tokens_details) == "table" and usage.input_tokens_details or nil
	local cached = details and details.cached_tokens or 0
	if type(cached) ~= "number" or cached < 0 or cached % 1 ~= 0 or cached > input then
		return tostring(input), "-", "-", "-"
	end
	local cache_pct = input > 0 and ("%.1f"):format(cached / input * 100) or "-"
	return tostring(input), tostring(cached), cached > 0 and "yes" or "no", cache_pct
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
---@param event table
---@return boolean
local function sendResponseEvent(res, event)
	local event_type = type(event.type) == "string" and event.type:match("^[%w._-]+$") or nil
	local prefix = event_type and "event: " .. event_type .. "\n" or ""
	local sent = res:send(prefix .. "data: " .. json.encode(event) .. "\n\n")
	return sent ~= nil
end

---@param res web.Response
---@return boolean
local function startEventStream(res)
	if res.headers_sent then return true end
	res.status = 200
	res.headers:set("Content-Type", "text/event-stream")
	res.headers:set("Cache-Control", "no-cache")
	res:set_chunked_encoding()
	return res:send_headers() ~= nil
end

---@param res web.Response
---@param model string
---@param completion_id string
---@param created integer
---@param delta table
---@param finish_reason string?
---@param include_usage boolean
---@return boolean
local function sendChunk(res, model, completion_id, created, delta, finish_reason, include_usage)
	return sendEvent(res, {
		id = completion_id,
		object = "chat.completion.chunk",
		created = created,
		model = model,
		choices = {{index = 0, delta = delta, finish_reason = finish_reason}},
		usage = include_usage and json.null or nil,
	})
end

---@param res web.Response
---@param model string
---@param completion_id string
---@param created integer
---@param usage openai.TokenUsage
local function sendUsageChunk(res, model, completion_id, created, usage)
	sendEvent(res, {
		id = completion_id,
		object = "chat.completion.chunk",
		created = created,
		model = model,
		choices = {},
		usage = ChatCompat.createCompletionUsage(usage),
	})
end

---@param request table
---@param models_set {[string]: boolean}
---@return string?
---@return string?
local function validateResponsesRequest(request, models_set)
	if type(request.model) ~= "string" or not models_set[request.model] then
		return "model is not available", "model_not_found"
	end
	if type(request.input) ~= "string" and not json.isArray(request.input) then
		return "input must be a string or an array", "invalid_input"
	end
	if request.instructions ~= nil and request.instructions ~= json.null
		and type(request.instructions) ~= "string"
	then
		return "instructions must be a string", "invalid_instructions"
	end
	if request.stream ~= nil and type(request.stream) ~= "boolean" then
		return "stream must be a boolean", "invalid_stream"
	end
	if request.store ~= nil and request.store ~= json.null and request.store ~= false then
		return "stateful Responses storage is not supported", "unsupported_store"
	end
	if request.background ~= nil and request.background ~= json.null and request.background ~= false then
		return "background Responses are not supported", "unsupported_background"
	end
	if ChatCompat.isPresent(request.previous_response_id) or ChatCompat.isPresent(request.conversation) then
		return "server-managed response state is not supported", "unsupported_response_state"
	end
	if request.reasoning ~= nil and request.reasoning ~= json.null then
		if not json.isObject(request.reasoning) then
			return "reasoning must be an object", "invalid_reasoning"
		end
		if request.reasoning.effort ~= nil and request.reasoning.effort ~= json.null
			and not ChatCompat.reasoning_efforts[request.reasoning.effort]
		then
			return "reasoning effort is invalid", "invalid_reasoning"
		end
	end
	if request.text ~= nil and request.text ~= json.null and not json.isObject(request.text) then
		return "text must be an object", "invalid_text"
	end
	if request.include ~= nil and request.include ~= json.null then
		if not json.isArray(request.include) then return "include must be an array", "invalid_include" end
		---@type any[]
		local include = request.include
		for _, value in ipairs(include) do
			if type(value) ~= "string" then return "include values must be strings", "invalid_include" end
		end
	end
	if request.tools ~= nil and request.tools ~= json.null and not json.isArray(request.tools) then
		return "tools must be an array", "invalid_tools"
	end
	if request.parallel_tool_calls ~= nil and type(request.parallel_tool_calls) ~= "boolean" then
		return "parallel_tool_calls must be a boolean", "invalid_parallel_tool_calls"
	end
	if request.prompt_cache_key ~= nil and (type(request.prompt_cache_key) ~= "string"
			or request.prompt_cache_key == "" or #request.prompt_cache_key > 64)
	then
		return "prompt_cache_key must contain 1 to 64 bytes", "invalid_prompt_cache_key"
	end
end

---@param res web.Response
---@param request table
---@param session_id string?
---@return integer status
---@return table? result
function ProxyServer:responses(res, request, session_id)
	local validation_err, validation_code = validateResponsesRequest(request, self.models_set)
	if validation_err then
		sendError(res, 400, validation_err, "invalid_request_error", assert(validation_code))
		return 400
	end

	local reasoning_effort = type(request.reasoning) == "table" and request.reasoning.effort or nil
	local verbosity = type(request.text) == "table" and request.text.verbosity or nil
	local requested_model = request.model --[[@as string]]
	local client = self.create_client(self.model_redirects[requested_model] or requested_model, reasoning_effort, {
		parallel_tool_calls = request.parallel_tool_calls,
		verbosity = verbosity,
		session_id = session_id or getPromptCacheSessionId(request.prompt_cache_key),
	})
	if request.stream ~= true then
		local response, _, provider_error = client:createResponse(request)
		if not response then
			if provider_error then return sendProviderError(res, provider_error) end
			sendError(res, 502, "upstream request failed", "upstream_error", "upstream_error")
			return 502
		end
		sendJson(res, response)
		return 200, response
	end

	local started = false
	local response, _, provider_error = client:createResponse(request, function(event)
		if not started then
			started = true
			if not startEventStream(res) then return false end
		end
		return sendResponseEvent(res, event)
	end)
	if not response then
		if not started then
			if provider_error then return sendProviderError(res, provider_error) end
			sendError(res, 502, "upstream request failed", "upstream_error", "upstream_error")
			return 502
		end
		res:send("")
		return 502
	end
	if not started then
		started = true
		if not startEventStream(res) then return 499 end
	end
	res:send("")
	return 200, response
end

---@param res web.Response
---@param request table
---@param session_id string?
---@return integer status
---@return table? result
function ProxyServer:complete(res, request, session_id)
	if type(request.model) ~= "string" or not self.models_set[request.model] then
		sendError(res, 400, "model is not available", "invalid_request_error", "model_not_found")
		return 400
	end
	local compat, message, code = ChatCompat.normalizeRequest(request)
	if not compat then
		sendError(res, 400, message, "invalid_request_error", code)
		return 400
	end

	local requested_model = request.model --[[@as string]]
	compat.client_options.session_id = session_id
		or getPromptCacheSessionId(compat.client_options.prompt_cache_key)
	local client = self.create_client(self.model_redirects[requested_model] or requested_model,
		compat.reasoning_effort, compat.client_options)
	local completion_id = "chatcmpl-" .. random.hex(16)
	local created = os.time()
	if not compat.stream then
		local message, _, provider_error = client:completeStream(compat.messages, compat.tools)
		if not message then
			if provider_error then
				return sendProviderError(res, provider_error)
			end
			sendError(res, 502, "upstream request failed", "upstream_error", "upstream_error")
			return 502
		end
		sendJson(res, ChatCompat.createCompletion(request.model, message, completion_id, created,
			compat.legacy_functions))
		return 200, message
	end

	local streamed_tool_calls = false
	if not startEventStream(res)
		or not sendChunk(res, request.model, completion_id, created, {role = "assistant"}, nil, compat.include_usage)
	then
		return 499
	end
	local message, completion_err, provider_error = client:completeStream(compat.messages, compat.tools, function(content)
		return sendChunk(res, request.model, completion_id, created, {content = content}, nil, compat.include_usage)
	end, function(content)
		return sendChunk(res, request.model, completion_id, created, {reasoning_content = content}, nil, compat.include_usage)
	end, function(delta)
		streamed_tool_calls = true
		return sendChunk(res, request.model, completion_id, created,
			ChatCompat.toolCallDelta(delta, compat.legacy_functions), nil, compat.include_usage)
	end)
	if not message then
		if completion_err == "downstream response stream closed" then
			res:send("")
			return 499
		end
		local error_body = provider_error or {
			message = "upstream request failed",
			type = "upstream_error",
			code = "upstream_error",
		}
		sendEvent(res, {error = {
			message = error_body.message,
			type = error_body.type,
			code = error_body.code,
			request_id = error_body.request_id,
		}})
		sendEvent(res, "[DONE]")
		res:send("")
		return 502
	end
	if not streamed_tool_calls then
		local delta = ChatCompat.terminalToolCalls(message, compat.legacy_functions)
		if delta then
			sendChunk(res, request.model, completion_id, created, delta, nil, compat.include_usage)
		end
	end
	sendChunk(res, request.model, completion_id, created, json.object(),
		ChatCompat.getFinishReason(message, compat.legacy_functions), compat.include_usage)
	if compat.include_usage and message.usage then
		sendUsageChunk(res, request.model, completion_id, created, message.usage)
	end
	sendEvent(res, "[DONE]")
	res:send("")
	return 200, message
end

---@param token string
---@return boolean
function ProxyServer:consumeRateLimit(token)
	local now = self.get_time()
	local window = self.request_windows[token]
	if not window or now - window.started_at >= 60 then
		self.request_windows[token] = {started_at = now, count = 1}
		return true
	elseif window.count >= self.max_requests_per_minute then
		return false
	end
	window.count = window.count + 1
	return true
end

---@param token string
---@return boolean
function ProxyServer:acquireRequest(token)
	local active = self.active_requests[token] or 0
	if active >= self.max_concurrent_requests_per_user then return false end
	self.active_requests[token] = active + 1
	return true
end

---@param token string
function ProxyServer:releaseRequest(token)
	local active = assert(self.active_requests[token]) - 1
	self.active_requests[token] = active > 0 and active or nil
end

---@param res web.Response
---@return integer status
function ProxyServer:usage(res)
	local usage, _, provider_error = self.fetch_usage()
	if not usage then
		if provider_error then return sendProviderError(res, provider_error) end
		sendError(res, 502, "upstream usage request failed", "upstream_error", "upstream_error")
		return 502
	end
	sendJson(res, usage)
	return 200
end

---@param req web.Request
---@param res web.Response
---@param path string
---@param metrics {request: table?}?
---@return integer status
---@return table? result
function ProxyServer:handleAuthenticated(req, res, path, metrics)
	if req.method == "GET" and path == "/v1/usage/history" and self.usage_repo then
		local history = self.usage_repo:history(os.time())
		history.model_redirects = self.model_redirects
		sendJson(res, history)
		return 200
	elseif req.method == "GET" and path == "/v1/usage" then
		return self:usage(res)
	elseif req.method == "GET" and path == "/v1/models" then
		local models = {}
		for _, model in ipairs(self.models) do
			table.insert(models, {id = model, object = "model", owned_by = "openai-subscription"})
		end
		sendJson(res, {object = "list", data = models})
		return 200
	elseif req.method == "POST" and (path == "/v1/chat/completions" or path == "/v1/responses") then
		local transfer_encodings = req.headers:getTable("Transfer-Encoding")
		local content_lengths = req.headers:getTable("Content-Length")
		if #transfer_encodings > 0 then
			sendError(res, 400, "Transfer-Encoding is not supported", "invalid_request_error", "unsupported_transfer_encoding")
			return 400
		elseif #content_lengths == 0 then
			sendError(res, 411, "Content-Length is required", "invalid_request_error", "length_required")
			return 411
		elseif #content_lengths ~= 1 then
			sendError(res, 400, "multiple Content-Length headers are not allowed", "invalid_request_error", "invalid_content_length")
			return 400
		end
		local content_length = tonumber(content_lengths[1])
		if not content_length then
			sendError(res, 400, "Content-Length is invalid", "invalid_request_error", "invalid_content_length")
			return 400
		elseif content_length > self.max_body_size then
			sendError(res, 413, "request body is too large", "invalid_request_error", "request_too_large")
			return 413
		end
		local body, receive_err = req:receive("*a")
		---@type table?, string?
		local request, decode_err
		if body then
			request, decode_err = json.decode_safe(body)
		end
		if type(request) ~= "table" then
			sendError(res, 400, "invalid JSON body: " .. tostring(decode_err or receive_err), "invalid_request_error", "invalid_json")
			return 400
		end
		local session_id, session_err = getSessionAffinity(req)
		if session_err then
			sendError(res, 400, session_err, "invalid_request_error", "invalid_session_affinity")
			return 400
		end
		if metrics then metrics.request = request end
		if path == "/v1/responses" then return self:responses(res, request, session_id) end
		return self:complete(res, request, session_id)
	end
	sendError(res, 404, "route not found", "invalid_request_error", "not_found")
	return 404
end

---@param req web.Request
---@param res web.Response
---@param ip string
function ProxyServer:handle(req, res, ip)
	local started_at = self.get_time()
	local user, token = self:authenticate(req)
	---@type integer
	local status
	local path = req.uri:match("^[^?]+") or req.uri
	---@type {request: table?, result: table?}
	local metrics = {}
	if req.method == "GET" and path == "/usage" then
		sendUsagePage(res)
		status = 200
	elseif not user then
		sendError(res, 401, "invalid access token", "authentication_error", "invalid_api_key")
		status = 401
	elseif not self:consumeRateLimit(assert(token)) then
		res.headers:set("Retry-After", 60)
		sendError(res, 429, "rate limit exceeded", "rate_limit_error", "rate_limit_exceeded")
		status = 429
	elseif not self:acquireRequest(assert(token)) then
		res.headers:set("Retry-After", 1)
		sendError(res, 429, "too many concurrent requests", "rate_limit_error", "concurrency_limit_exceeded")
		status = 429
	else
		---@type string?
		local handle_err
		local ok = xpcall(function()
			status, metrics.result = self:handleAuthenticated(req, res, path, metrics)
		end, function(err)
			handle_err = debug.traceback(err, 2)
		end)
		self:releaseRequest(assert(token))
		if not ok then error(handle_err, 0) end
	end
	local requested_model = metrics.request and metrics.request.model
	local model = type(requested_model) == "string" and self.models_set[requested_model]
		and (self.model_redirects[requested_model] or requested_model) or "-"
	if self.usage_repo and user and req.method == "POST"
		and (path == "/v1/chat/completions" or path == "/v1/responses") then
		self.usage_repo:record(os.time(), user, status, metrics.request, metrics.result,
			model ~= "-" and model or nil)
	end
	local session_source, session_hash = getLogSession(req, metrics.request)
	local input_tokens, cached_tokens, cache_hit, cache_pct = getLogCache(metrics.result)
	self.logger(("user=%s ip=%s method=%s path=%s status=%d duration=%.3fs model=%s "
			.. "session_source=%s session=%s input_tokens=%s cached_tokens=%s cache_hit=%s cache_pct=%s")
		:format(
			sanitizeLogValue(user or "-"),
			sanitizeLogValue(ip),
			sanitizeLogValue(req.method),
			sanitizeLogValue(path),
			status,
			self.get_time() - started_at,
			sanitizeLogValue(model),
			sanitizeLogValue(session_source),
			sanitizeLogValue(session_hash),
			input_tokens,
			cached_tokens,
			cache_hit,
			cache_pct
		))
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
