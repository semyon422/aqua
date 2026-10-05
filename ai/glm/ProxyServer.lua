local class = require("class")
local json = require("web.json")
local random = require("web.random")
---@type {gettime: fun(): number}
local socket = require("socket")
local HttpServer = require("web.http.Server")

---@class glm.ProxyUser
---@field name string
---@field access_token string

---@class glm.UntrustedObject
---@field [any] any

---@class glm.UntrustedFunctionCall: glm.UntrustedObject
---@field name any?
---@field arguments any?

---@class glm.UntrustedToolCall: glm.UntrustedObject
---@field id any?
---@field type any?
---@field ["function"] glm.UntrustedFunctionCall?

---@class glm.UntrustedMessage: glm.UntrustedObject
---@field role any?
---@field content any?
---@field tool_calls any?
---@field tool_call_id any?

---@class glm.UntrustedContentPart: glm.UntrustedObject
---@field type any?
---@field text any?

---@class glm.ToolSchema: glm.UntrustedObject
---@field type any?
---@field ["function"] glm.UntrustedFunctionCall?

---@class glm.ProxyServerOptions
---@field scheduler web.CosocketScheduler
---@field users glm.ProxyUser[]
---@field models string[]
---@field model_redirects {[string]: string}?
---@field create_client fun(): glm.Client
---@field thinking "enabled"|"disabled"?
---@field tool_stream boolean?
---@field fetch_usage (fun(): table?, string?, glm.ProviderError?)?
---@field logger (fun(line: string))?
---@field max_body_size integer?
---@field client_timeout number?
---@field max_clients integer?
---@field max_concurrent_requests_per_user integer?
---@field max_requests_per_minute integer?
---@field get_time (fun(): number)?

--- An authenticated Chat Completions proxy for a GLM coding plan. It serves
--- `POST /v1/chat/completions` plus the read-only `GET /v1/models` and
--- `GET /v1/usage` routes; usage dashboards, usage history, and a web frontend
--- are out of scope.
---@class glm.ProxyServer
---@operator call: glm.ProxyServer
---@field users_by_token {[string]: string}
---@field models string[]
---@field models_set {[string]: boolean}
---@field model_redirects {[string]: string}
---@field create_client fun(): glm.Client
---@field thinking "enabled"|"disabled"?
---@field tool_stream boolean
---@field fetch_usage fun(): table?, string?, glm.ProviderError?
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

---@param options glm.ProxyServerOptions
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
---@param provider_error glm.ProviderError
---@return integer status
local function sendProviderError(res, provider_error)
	local status = provider_error.status
	if status < 400 or status > 599 then status = 502 end
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

---@param value any
---@return boolean
local function isPresent(value)
	return value ~= nil and value ~= json.null
end

---@param value any
---@return boolean
local function isPositiveInteger(value)
	return type(value) == "number" and value >= 1 and value % 1 == 0
end

---@param content any
---@return string?
local function normalizeContent(content)
	if type(content) == "string" then return content end
	if content == nil or content == json.null then return nil end
	if not json.isArray(content) then return end
	---@type string[]
	local text_parts = {}
	---@cast content glm.UntrustedContentPart[]
	for _, part in ipairs(content) do
		if not json.isObject(part) or (part.type ~= "text" and part.type ~= "input_text")
			or type(part.text) ~= "string"
		then
			return
		end
		table.insert(text_parts, part.text)
	end
	return table.concat(text_parts)
end

---@param messages any
---@return glm.UntrustedMessage[]? normalized
function ProxyServer.normalizeMessages(messages)
	if not json.isArray(messages) or #messages == 0 then return end
	---@type glm.UntrustedMessage[]
	local normalized = {}
	for _, message in ipairs(messages) do
		if not json.isObject(message) then return end
		---@cast message glm.UntrustedMessage
		local role = message.role
		if role == "developer" then role = "system" end
		if role ~= "system" and role ~= "user" and role ~= "assistant" and role ~= "tool" then
			return
		end
		---@type glm.UntrustedMessage
		local copy = {role = role}
		local content = normalizeContent(message.content)
		if content ~= nil then
			copy.content = content
		elseif role == "system" or role == "user" or role == "tool" then
			return
		end
		if role == "tool" then
			if type(message.tool_call_id) ~= "string" or message.tool_call_id == "" then return end
			copy.tool_call_id = message.tool_call_id
		end
		if isPresent(message.tool_calls) then
			if role ~= "assistant" or not json.isArray(message.tool_calls) then return end
			---@type glm.UntrustedToolCall[]
			local tool_calls = {}
			for index, tool_call in ipairs(message.tool_calls) do
				if not json.isObject(tool_call) or type(tool_call.id) ~= "string"
					or tool_call.type ~= "function" or not json.isObject(tool_call["function"])
					or type(tool_call["function"].name) ~= "string"
					or type(tool_call["function"].arguments) ~= "string"
				then
					return
				end
				tool_calls[index] = {
					id = tool_call.id,
					type = "function",
					["function"] = {
						name = tool_call["function"].name,
						arguments = tool_call["function"].arguments,
					},
				}
			end
			copy.tool_calls = tool_calls
		end
		table.insert(normalized, copy)
	end
	return normalized
end

---@param tools any
---@return glm.ToolSchema[]? normalized
function ProxyServer.normalizeTools(tools)
	if not isPresent(tools) then return {} end
	if not json.isArray(tools) then return end
	---@type glm.ToolSchema[]
	local normalized = {}
	for _, tool in ipairs(tools) do
		if not json.isObject(tool) or tool.type ~= "function" or not json.isObject(tool["function"]) then
			return
		end
		local schema = tool["function"]
		if type(schema.name) ~= "string" or schema.name == "" or not json.isObject(schema.parameters) then
			return
		end
		if schema.description ~= nil and schema.description ~= json.null and type(schema.description) ~= "string" then
			return
		end
		table.insert(normalized, {
			type = "function",
			["function"] = {
				name = schema.name,
				description = schema.description,
				parameters = schema.parameters,
			},
		})
	end
	return normalized
end

---@param tool_choice any
---@param tools glm.ToolSchema[]
---@return any normalized
---@return string? err
local function normalizeToolChoice(tool_choice, tools)
	if not isPresent(tool_choice) then return end
	if tool_choice == "none" or tool_choice == "auto" or tool_choice == "required" then
		if #tools == 0 then return nil, "tool_choice requires tools" end
		return tool_choice
	end
	if not json.isObject(tool_choice) or tool_choice.type ~= "function"
		or not json.isObject(tool_choice["function"])
		or type(tool_choice["function"].name) ~= "string" or tool_choice["function"].name == ""
	then
		return nil, "tool_choice has an unsupported shape"
	end
	if #tools == 0 then return nil, "tool_choice requires tools" end
	---@type string
	local name = tool_choice["function"].name
	for _, tool in ipairs(tools) do
		if tool["function"].name == name then
			return {type = "function", ["function"] = {name = name}}
		end
	end
	return nil, "tool_choice names an unavailable function"
end

---@param thinking any
---@return {[string]: any}? normalized
---@return string? err
local function normalizeThinking(thinking)
	if not isPresent(thinking) then return end
	if not json.isObject(thinking) or (thinking.type ~= "enabled" and thinking.type ~= "disabled") then
		return nil, "thinking must be an object with type enabled or disabled"
	end
	if thinking.clear_thinking ~= nil and thinking.clear_thinking ~= json.null
		and type(thinking.clear_thinking) ~= "boolean"
	then
		return nil, "thinking clear_thinking must be a boolean"
	end
	---@type {[string]: any}
	local normalized = {type = thinking.type}
	if thinking.clear_thinking ~= nil and thinking.clear_thinking ~= json.null then
		normalized.clear_thinking = thinking.clear_thinking
	end
	return normalized
end

---@param response_format any
---@return table? normalized
---@return string? err
local function normalizeResponseFormat(response_format)
	if not isPresent(response_format) then return end
	if not json.isObject(response_format) then return nil, "response_format must be an object" end
	if response_format.type == "text" or response_format.type == "json_object" then
		return {type = response_format.type}
	end
	if response_format.type ~= "json_schema" or not json.isObject(response_format.json_schema) then
		return nil, "response_format has an unsupported shape"
	end
	local schema = response_format.json_schema
	if type(schema.name) ~= "string" or schema.name == "" or not json.isObject(schema.schema) then
		return nil, "response_format json_schema is invalid"
	end
	if schema.description ~= nil and schema.description ~= json.null and type(schema.description) ~= "string" then
		return nil, "response_format json_schema description is invalid"
	end
	if schema.strict ~= nil and schema.strict ~= json.null and type(schema.strict) ~= "boolean" then
		return nil, "response_format json_schema strict is invalid"
	end
	return {
		type = "json_schema",
		json_schema = {
			name = schema.name,
			description = schema.description,
			schema = schema.schema,
			strict = schema.strict,
		},
	}
end

---@param request table
---@return string? err
---@return string? code
local function validateUnsupportedParameters(request)
	if isPresent(request.n) and request.n ~= 1 then
		return "n values other than 1 are not supported", "unsupported_parameter"
	end
	if isPresent(request.seed) then return "seed is not supported", "unsupported_parameter" end
	if isPresent(request.logprobs) then return "logprobs is not supported", "unsupported_parameter" end
	if isPresent(request.top_logprobs) then return "top_logprobs is not supported", "unsupported_parameter" end
	if isPresent(request.logit_bias) then return "logit_bias is not supported", "unsupported_parameter" end
	if isPresent(request.store) then return "store is not supported", "unsupported_parameter" end
	if isPresent(request.user) then return "user is not supported", "unsupported_parameter" end
	if isPresent(request.prompt_cache_key) then return "prompt_cache_key is not supported", "unsupported_parameter" end
end

---@param request table
---@param models_set {[string]: boolean}
---@param model_redirects {[string]: string}
---@param default_thinking "enabled"|"disabled"?
---@param default_tool_stream boolean
---@return table? upstream_body
---@return string? public_model
---@return boolean stream
---@return boolean include_usage
---@return string? err
---@return string? code
function ProxyServer.normalizeRequest(request, models_set, model_redirects, default_thinking, default_tool_stream)
	if type(request.model) ~= "string" or not models_set[request.model] then
		return nil, nil, false, false, "model is not available", "model_not_found"
	end
	local public_model = request.model
	local unsupported_err, unsupported_code = validateUnsupportedParameters(request)
	if unsupported_err then
		return nil, nil, false, false, unsupported_err, unsupported_code
	end
	local messages = ProxyServer.normalizeMessages(request.messages)
	if not messages then
		return nil, nil, false, false, "messages have an unsupported shape", "invalid_messages"
	end
	local tools = ProxyServer.normalizeTools(request.tools)
	if not tools then
		return nil, nil, false, false, "tools must be an array of function definitions", "invalid_tools"
	end
	local tool_choice, tool_choice_err = normalizeToolChoice(request.tool_choice, tools)
	if tool_choice_err then
		return nil, nil, false, false, tool_choice_err, "invalid_tool_choice"
	end
	local thinking, thinking_err = normalizeThinking(request.thinking)
	if thinking_err then
		return nil, nil, false, false, thinking_err, "invalid_thinking"
	end
	local response_format, response_format_err = normalizeResponseFormat(request.response_format)
	if response_format_err then
		return nil, nil, false, false, response_format_err, "invalid_response_format"
	end

	local stream = request.stream == true
	local include_usage = false
	if isPresent(request.stream_options) then
		if not stream or not json.isObject(request.stream_options) then
			return nil, nil, false, false, "stream_options requires stream=true and an object", "invalid_stream_options"
		end
		if request.stream_options.include_usage ~= nil and request.stream_options.include_usage ~= json.null then
			if type(request.stream_options.include_usage) ~= "boolean" then
				return nil, nil, false, false, "stream_options include_usage must be a boolean", "invalid_stream_options"
			end
			include_usage = request.stream_options.include_usage
		end
	end
	if isPresent(request.reasoning_effort) and type(request.reasoning_effort) ~= "string" then
		return nil, nil, false, false, "reasoning_effort must be a string", "invalid_reasoning_effort"
	end
	if request.max_completion_tokens ~= nil and request.max_tokens ~= nil then
		return nil, nil, false, false, "max_completion_tokens and max_tokens are mutually exclusive", "invalid_max_tokens"
	end
	local max_tokens = request.max_completion_tokens or request.max_tokens
	if max_tokens ~= nil and not isPositiveInteger(max_tokens) then
		return nil, nil, false, false, "completion token limit must be a positive integer", "invalid_max_tokens"
	end
	if isPresent(request.temperature)
		and (type(request.temperature) ~= "number" or request.temperature < 0 or request.temperature > 2)
	then
		return nil, nil, false, false, "temperature must be between 0 and 2", "invalid_temperature"
	end
	if isPresent(request.top_p)
		and (type(request.top_p) ~= "number" or request.top_p < 0 or request.top_p > 1)
	then
		return nil, nil, false, false, "top_p must be between 0 and 1", "invalid_top_p"
	end
	for _, name in ipairs({"frequency_penalty", "presence_penalty"}) do
		---@type any
		local value = request[name]
		if isPresent(value) and (type(value) ~= "number" or value < -2 or value > 2) then
			return nil, nil, false, false, name .. " must be between -2 and 2", "invalid_" .. name
		end
	end
	if isPresent(request.stop) then
		if type(request.stop) == "string" then
			if request.stop == "" then
				return nil, nil, false, false, "stop must not be empty", "invalid_stop"
			end
		elseif not json.isArray(request.stop) then
			return nil, nil, false, false, "stop must be a string or an array of strings", "invalid_stop"
		else
			for _, stop_value in ipairs(request.stop) do
				if type(stop_value) ~= "string" or stop_value == "" then
					return nil, nil, false, false, "stop must be a string or an array of strings", "invalid_stop"
				end
			end
		end
	end
	if isPresent(request.parallel_tool_calls) and type(request.parallel_tool_calls) ~= "boolean" then
		return nil, nil, false, false, "parallel_tool_calls must be a boolean", "invalid_parallel_tool_calls"
	end
	if isPresent(request.tool_stream) and type(request.tool_stream) ~= "boolean" then
		return nil, nil, false, false, "tool_stream must be a boolean", "invalid_tool_stream"
	end

	---@type table
	local body = {
		model = model_redirects[public_model] or public_model,
		messages = messages,
		stream = stream,
	}
	if #tools > 0 then
		body.tools = tools
		if tool_choice then body.tool_choice = tool_choice end
		if isPresent(request.parallel_tool_calls) then
			body.parallel_tool_calls = request.parallel_tool_calls
		end
		if isPresent(request.tool_stream) then
			body.tool_stream = request.tool_stream
		elseif default_tool_stream then
			body.tool_stream = true
		end
	elseif tool_choice then
		body.tool_choice = tool_choice
	end
	if max_tokens then body.max_tokens = max_tokens end
	if isPresent(request.temperature) then body.temperature = request.temperature end
	if isPresent(request.top_p) then body.top_p = request.top_p end
	for _, name in ipairs({"frequency_penalty", "presence_penalty"}) do
		---@type any
		local value = request[name]
		if isPresent(value) then body[name] = value end
	end
	if isPresent(request.stop) then body.stop = request.stop end
	if thinking then
		body.thinking = thinking
	elseif isPresent(request.reasoning_effort) then
		body.thinking = {type = "enabled"}
	elseif default_thinking then
		body.thinking = {type = default_thinking}
	end
	if isPresent(request.reasoning_effort) then body.reasoning_effort = request.reasoning_effort end
	if response_format then body.response_format = response_format end
	return body, public_model, stream, include_usage
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
	return sendEvent(res, {
		id = completion_id,
		object = "chat.completion.chunk",
		created = created,
		model = model,
		choices = {{index = 0, delta = delta, finish_reason = finish_reason}},
		usage = include_usage and json.null or nil,
	})
end

---@param delta glm.MessageDelta
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
	sendEvent(res, {
		id = completion_id,
		object = "chat.completion.chunk",
		created = created,
		model = model,
		choices = {},
		usage = createCompletionUsage(usage),
	})
end

---@param res web.Response
---@param request table
---@return integer status
function ProxyServer:complete(res, request)
	local body, public_model, stream, include_usage, err, code = ProxyServer.normalizeRequest(
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
		if provider_error then return sendProviderError(res, provider_error) end
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
				table.insert(models, {id = model, object = "model", owned_by = "glm-coding-plan"})
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
