local class = require("class")
local json = require("web.json")
local random = require("web.random")
local HttpServer = require("web.http.Server")
local Protocol = require("ai.zai.Protocol")
local ChatProtocol = require("ai.openai.ChatCompletionsProtocol")

---@class zai.ProxyUser
---@field name string
---@field access_token string

---@class zai.ProxyServerOptions
---@field scheduler web.CosocketScheduler
---@field users zai.ProxyUser[]
---@field models string[]
---@field model_redirects {[string]: string}?
---@field create_client fun(): zai.Client
---@field thinking "enabled"|"disabled"?
---@field tool_stream boolean?
---@field fetch_usage (fun(): table?, string?, openai.UsageFetchError?)?
---@field logger (fun(line: string))?
---@field max_body_size integer?
---@field client_timeout number?
---@field max_clients integer?
---@field max_concurrent_requests_per_user integer?
---@field max_requests_per_minute integer?
---@field get_time fun(): number

--- An authenticated Chat Completions proxy for a GLM coding plan. It serves
--- `POST /v1/chat/completions` plus the read-only `GET /v1/models` and
--- `GET /v1/usage` routes; usage dashboards, usage history, and a web frontend
--- are out of scope.
---@class zai.ProxyServer
---@operator call: zai.ProxyServer
---@field users_by_token {[string]: string}
---@field models string[]
---@field models_set {[string]: boolean}
---@field model_redirects {[string]: string}
---@field create_client fun(): zai.Client
---@field thinking "enabled"|"disabled"?
---@field tool_stream boolean
---@field fetch_usage fun(): table?, string?, openai.UsageFetchError?
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
ProxyServer.tool_stream = true

local finish_reasons = {
	stop = "stop",
	length = "length",
	tool_calls = "tool_calls",
	function_call = "tool_calls",
	content_filter = "content_filter",
}

---@param options zai.ProxyServerOptions
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
	assert(options.thinking == nil or options.thinking == "enabled" or options.thinking == "disabled",
		"thinking must be enabled or disabled")
	self.thinking = options.thinking
	assert(type(options.tool_stream) ~= "boolean" or options.tool_stream == true or options.tool_stream == false,
		"tool_stream must be a boolean")
	self.tool_stream = options.tool_stream ~= false
	self.fetch_usage = options.fetch_usage or function() return nil, "usage is not configured" end
	self.logger = options.logger or print
	self.max_body_size = options.max_body_size or self.max_body_size
	self.max_concurrent_requests_per_user = options.max_concurrent_requests_per_user or self.max_concurrent_requests_per_user
	self.max_requests_per_minute = options.max_requests_per_minute or self.max_requests_per_minute
	self.active_requests = {}
	self.request_windows = {}
	assert(type(options.get_time) == "function", "get_time is required")
	self.get_time = options.get_time
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
---@param provider_error zai.ProviderError|openai.UsageFetchError
---@return integer status
local function sendProviderError(res, provider_error)
	local status = provider_error.status
	if type(status) ~= "number" or status % 1 ~= 0 or status < 400 or status > 599 then status = 502 end
	sendError(res, status, provider_error.message, provider_error.type, provider_error.code)
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
---@param event table|string
---@return boolean
local function sendEvent(res, event)
	local data = type(event) == "string" and event or json.encode(event)
	local sent = res:send("data: " .. data .. "\n\n")
	return sent ~= nil
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
	return sendEvent(res, ChatProtocol.chunk(completion_id, created, model, delta, finish_reason, include_usage))
end

---@param delta zai.MessageDelta
---@return table? relayed
local function relayDelta(delta)
	---@type table
	local relayed = {}
	if type(delta.content) == "string" and delta.content ~= "" then
		relayed.content = delta.content
	end
	if type(delta.reasoning_content) == "string" and delta.reasoning_content ~= "" then
		relayed.reasoning_content = delta.reasoning_content
	end
	if type(delta.tool_calls) == "table" then
		relayed.tool_calls = delta.tool_calls
	end
	if next(relayed) then return relayed end
end

---@param usage table
---@return table
local function createCompletionUsage(usage)
	return {
		prompt_tokens = usage.prompt_tokens,
		completion_tokens = usage.completion_tokens,
		total_tokens = usage.total_tokens,
		prompt_tokens_details = usage.prompt_tokens_details,
		completion_tokens_details = usage.completion_tokens_details,
	}
end

---@param res web.Response
---@param model string
---@param completion_id string
---@param created integer
---@param usage table
local function sendUsageChunk(res, model, completion_id, created, usage)
	sendEvent(res, ChatProtocol.usageChunk(completion_id, created, model, createCompletionUsage(usage)))
end

---@param res web.Response
---@param request table
---@return integer status
function ProxyServer:complete(res, request)
	local body, public_model, stream, include_usage, err, code = Protocol.normalizeRequest(
		request, self.models_set, self.model_redirects, self.thinking, self.tool_stream)
	if not body then
		sendError(res, 400, assert(err), "invalid_request_error", assert(code))
		return 400
	end
	local client = self.create_client()
	local completion_id = "chatcmpl-" .. random.hex(16)
	local created = os.time()

	if not stream then
		local completion, _, provider_error = client:complete(body)
		if not completion then
			if provider_error then return sendProviderError(res, provider_error) end
			sendError(res, 502, "upstream request failed", "upstream_error", "upstream_error")
			return 502
		end
		completion.model = public_model
		local encoded = json.encode(completion)
		res.status = 200
		res.headers:set("Content-Type", "application/json")
		res.headers:set("Cache-Control", "no-store")
		res:set_length(#encoded)
		res:send(encoded)
		return 200
	end

	if not startEventStream(res)
		or not sendChunk(res, public_model, completion_id, created, {role = "assistant"}, nil, include_usage)
	then
		return 499
	end
	local message, completion_err, provider_error = client:completeStream(body, function(delta)
		local relayed = relayDelta(delta)
		if not relayed then return true end
		return sendChunk(res, public_model, completion_id, created, relayed, nil, include_usage)
	end)
	if not message then
		if completion_err == "downstream response stream closed" then
			res:send("")
			return 499
		end
		local error_body = provider_error or {
			message = completion_err or "upstream request failed",
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
	local finish_reason = finish_reasons[message.finish_reason or ""]
	if not finish_reason then
		sendEvent(res, {error = {
			message = "unsupported upstream finish_reason: " .. tostring(message.finish_reason),
			type = "upstream_error",
			code = "unsupported_finish_reason",
		}})
		sendEvent(res, "[DONE]")
		res:send("")
		return 502
	end
	sendChunk(res, public_model, completion_id, created, json.object(), finish_reason, include_usage)
	if include_usage and message.usage then
		sendUsageChunk(res, public_model, completion_id, created, message.usage)
	end
	sendEvent(res, "[DONE]")
	res:send("")
	return 200
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

---@param value any
---@return string
local function sanitizeLogValue(value)
	return string.gsub(tostring(value), "[%c\127]", "?")
end

---@param res web.Response
---@return integer status
function ProxyServer:usage(res)
	local usage, _, provider_error = self.fetch_usage()
	if not usage then
		-- Local/transport failures have no upstream HTTP status.
		if provider_error and provider_error.status then return sendProviderError(res, provider_error) end
		sendError(res, 502, "upstream usage request failed", "upstream_error", "upstream_error")
		return 502
	end
	sendJson(res, usage)
	return 200
end

---@param req web.Request
---@param res web.Response
---@param ip string
function ProxyServer:handle(req, res, ip)
	local started_at = self.get_time()
	local user, token = self:authenticate(req)
	---@type integer
	local status
	---@type string?
	local handle_err
	local path = req.uri:match("^[^?]+") or req.uri
	if req.method == "GET" and path == "/v1/models" then
		-- Read-only catalog route: authenticated like inference, but it does not
		-- consume request-rate or concurrency limits.
		if not user then
			sendError(res, 401, "invalid access token", "authentication_error", "invalid_api_key")
			status = 401
		else
			local models = {}
			for _, model in ipairs(self.models) do
				table.insert(models, {id = model, object = "model", owned_by = "zai-coding-plan"})
			end
			sendJson(res, {object = "list", data = models})
			status = 200
		end
	elseif req.method == "GET" and path == "/v1/usage" then
		-- Read-only monitor route: authenticated like inference, but it does not
		-- consume request-rate or concurrency limits.
		if not user then
			sendError(res, 401, "invalid access token", "authentication_error", "invalid_api_key")
			status = 401
		else
			local ok = xpcall(function()
				status = self:usage(res)
			end, function(err)
				handle_err = debug.traceback(err, 2)
			end)
			if not ok then error(handle_err, 0) end
		end
	elseif req.method ~= "POST" or path ~= "/v1/chat/completions" then
		sendError(res, 404, "route not found", "invalid_request_error", "not_found")
		status = 404
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
		local transfer_encodings = req.headers:getTable("Transfer-Encoding")
		local content_lengths = req.headers:getTable("Content-Length")
		if #transfer_encodings > 0 then
			sendError(res, 400, "Transfer-Encoding is not supported", "invalid_request_error", "unsupported_transfer_encoding")
			status = 400
		elseif #content_lengths == 0 then
			sendError(res, 411, "Content-Length is required", "invalid_request_error", "length_required")
			status = 411
		elseif #content_lengths ~= 1 then
			sendError(res, 400, "multiple Content-Length headers are not allowed", "invalid_request_error", "invalid_content_length")
			status = 400
		else
			local content_length = tonumber(content_lengths[1])
			if not content_length then
				sendError(res, 400, "Content-Length is invalid", "invalid_request_error", "invalid_content_length")
				status = 400
			elseif content_length > self.max_body_size then
				sendError(res, 413, "request body is too large", "invalid_request_error", "request_too_large")
				status = 413
			else
				local body, receive_err = req:receive("*a")
				local request, decode_err
				if body then
					request, decode_err = json.decode_safe(body)
				end
				if type(request) ~= "table" then
					sendError(res, 400, "invalid JSON body: " .. tostring(decode_err or receive_err), "invalid_request_error", "invalid_json")
					status = 400
				else
					xpcall(function()
						status = self:complete(res, request)
					end, function(handle_error)
						handle_err = debug.traceback(handle_error, 2)
					end)
				end
			end
		end
		self:releaseRequest(assert(token))
		if handle_err then error(handle_err, 0) end
	end
	self.logger(("user=%s ip=%s method=%s path=%s status=%d duration=%.3fs")
		:format(
			sanitizeLogValue(user or "-"),
			sanitizeLogValue(ip),
			sanitizeLogValue(req.method),
			sanitizeLogValue(path),
			status,
			self.get_time() - started_at
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
