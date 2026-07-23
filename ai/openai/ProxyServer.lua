local class = require("class")
local json = require("web.json")
local random = require("web.random")
local socket = require("socket")
local HttpServer = require("web.http.Server")

---@class aqua.openai.ProxyUser
---@field name string
---@field access_token string

---@class aqua.openai.ProxyClient
---@field completeStream fun(self: aqua.openai.ProxyClient, messages: aqua.openai.Message[], tools: aqua.openai.ToolSchema[]?, on_text_delta: (fun(content: string))?, on_reasoning_delta: (fun(content: string))?, on_tool_call_delta: (fun(delta: aqua.openai.ToolCallDelta))?): aqua.openai.Message?, string?, aqua.openai.ProviderError?
---@field createResponse fun(self: aqua.openai.ProxyClient, request: table, on_event: (fun(event: table): boolean?)?): table?, string?, aqua.openai.ProviderError?

---@class aqua.openai.ProxyRequestOptions
---@field prompt_cache_key string?
---@field prompt_cache_options aqua.openai.PromptCacheOptions?
---@field tool_choice "none"|"auto"|"required"|aqua.openai.ResponsesFunctionToolChoice?
---@field parallel_tool_calls boolean
---@field verbosity "low"|"medium"|"high"?
---@field text_format aqua.openai.ResponsesTextFormat?

---@class aqua.openai.ProxyServerOptions
---@field scheduler web.CosocketScheduler
---@field users aqua.openai.ProxyUser[]
---@field models string[]
---@field create_client fun(model: string, reasoning_effort: aqua.openai.ReasoningEffort?, request_options: aqua.openai.ProxyRequestOptions): aqua.openai.ProxyClient
---@field logger (fun(line: string))?
---@field max_body_size integer?
---@field client_timeout number?
---@field max_clients integer?
---@field max_concurrent_requests_per_user integer?
---@field max_requests_per_minute integer?
---@field get_time (fun(): number)?

---@class aqua.openai.ProxyServer
---@operator call: aqua.openai.ProxyServer
---@field users_by_token {[string]: string}
---@field models string[]
---@field models_set {[string]: boolean}
---@field create_client fun(model: string, reasoning_effort: aqua.openai.ReasoningEffort?, request_options: aqua.openai.ProxyRequestOptions): aqua.openai.ProxyClient
---@field logger fun(line: string)
---@field max_body_size integer
---@field max_concurrent_requests_per_user integer
---@field max_requests_per_minute integer
---@field active_requests {[string]: integer}
---@field request_windows {[string]: {started_at: number, count: integer}}
---@field get_time fun(): number
---@field http_server web.HttpServer
local ProxyServer = class()

ProxyServer.max_body_size = 1024 * 1024
ProxyServer.max_clients = 64
ProxyServer.max_concurrent_requests_per_user = 4
ProxyServer.max_requests_per_minute = 120

local reasoning_efforts = {
	none = true,
	minimal = true,
	low = true,
	medium = true,
	high = true,
	xhigh = true,
	max = true,
}

local verbosities = {
	low = true,
	medium = true,
	high = true,
}

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
---@param provider_error aqua.openai.ProviderError
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
	res:set_length(#encoded)
	res:send(encoded)
end

---@param value any
---@return string
local function sanitizeLogValue(value)
	return tostring(value):gsub("[%c\127]", "?")
end

---@param usage aqua.openai.TokenUsage
---@return table
local function createCompletionUsage(usage)
	return {
		prompt_tokens = usage.input_tokens,
		completion_tokens = usage.output_tokens,
		total_tokens = usage.total_tokens,
		prompt_tokens_details = usage.input_tokens_details,
		completion_tokens_details = usage.output_tokens_details,
	}
end

---@param message aqua.openai.Message
---@param legacy_functions boolean
---@return "stop"|"length"|"tool_calls"|"content_filter"|"function_call"
local function getFinishReason(message, legacy_functions)
	local finish_reason = message.finish_reason or (message.tool_calls and "tool_calls" or "stop")
	if legacy_functions and finish_reason == "tool_calls" then return "function_call" end
	return finish_reason
end

---@param model string
---@param message aqua.openai.Message
---@param completion_id string
---@param created integer
---@param legacy_functions boolean
---@return table
local function createCompletion(model, message, completion_id, created, legacy_functions)
	local output_message = {
		role = "assistant",
		content = message.content or "",
	}
	if message.reasoning_content then output_message.reasoning_content = message.reasoning_content end
	if legacy_functions and message.tool_calls then
		output_message.content = message.content ~= "" and message.content or json.null
		output_message.function_call = message.tool_calls[1]["function"]
	elseif message.tool_calls then
		output_message.tool_calls = message.tool_calls
	end
	local completion = {
		id = completion_id,
		object = "chat.completion",
		created = created,
		model = model,
		choices = {{
			index = 0,
			message = output_message,
			finish_reason = getFinishReason(message, legacy_functions),
		}},
	}
	if message.usage then completion.usage = createCompletionUsage(message.usage) end
	return completion
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
---@param include_usage boolean
local function sendChunk(res, model, completion_id, created, delta, finish_reason, include_usage)
	sendEvent(res, {
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
---@param usage aqua.openai.TokenUsage
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

---@param content any
---@param role string
---@return string|table[]?
local function normalizeContent(content, role)
	if type(content) == "string" then return content end
	if not json.isArray(content) then return end
	local text_parts = {}
	local input_parts = {}
	local has_non_text = false
	local has_breakpoint = false
	for _, part in ipairs(content) do
		if not json.isObject(part) then return end
		local breakpoint
		if part.prompt_cache_breakpoint ~= nil then
			if not json.isObject(part.prompt_cache_breakpoint)
				or part.prompt_cache_breakpoint.mode ~= "explicit"
			then
				return
			end
			for key in pairs(part.prompt_cache_breakpoint) do
				if key ~= "mode" then return end
			end
			breakpoint = {mode = "explicit"}
			has_breakpoint = true
		end
		if (part.type == "text" or part.type == "input_text") and type(part.text) == "string" then
			table.insert(text_parts, part.text)
			table.insert(input_parts, {
				type = "input_text",
				text = part.text,
				prompt_cache_breakpoint = breakpoint,
			})
		elseif role == "assistant" and part.type == "refusal" and type(part.refusal) == "string" then
			if breakpoint then return end
			table.insert(text_parts, part.refusal)
		elseif role == "user" and part.type == "image_url" then
			local image = part.image_url
			if type(image) ~= "table" or type(image.url) ~= "string" or image.url == "" then return end
			local detail = image.detail or "auto"
			if detail ~= "auto" and detail ~= "low" and detail ~= "high" then return end
			table.insert(input_parts, {
				type = "input_image",
				image_url = image.url,
				detail = detail,
				prompt_cache_breakpoint = breakpoint,
			})
			has_non_text = true
		elseif role == "user" and part.type == "input_audio" then
			if breakpoint then return end
			local audio = part.input_audio
			if type(audio) ~= "table" or type(audio.data) ~= "string" or audio.data == ""
				or (audio.format ~= "wav" and audio.format ~= "mp3")
			then
				return
			end
			table.insert(input_parts, {
				type = "input_audio",
				input_audio = {data = audio.data, format = audio.format},
			})
			has_non_text = true
		elseif role == "user" and part.type == "file" then
			local file = part.file
			if type(file) ~= "table" then return end
			local has_data = type(file.file_data) == "string" and file.file_data ~= ""
			local has_id = type(file.file_id) == "string" and file.file_id ~= ""
			if not has_data and not has_id then return end
			if file.filename ~= nil and type(file.filename) ~= "string" then return end
			table.insert(input_parts, {
				type = "input_file",
				file_data = has_data and file.file_data or nil,
				file_id = has_id and file.file_id or nil,
				filename = file.filename,
				prompt_cache_breakpoint = breakpoint,
			})
			has_non_text = true
		else
			return
		end
	end
	if (role == "user" or role == "developer" or role == "system") and (has_non_text or has_breakpoint) then
		return input_parts
	end
	return table.concat(text_parts)
end

---@param options any
---@return aqua.openai.PromptCacheOptions?
---@return string?
local function normalizePromptCacheOptions(options)
	if options == nil then return end
	if not json.isObject(options) then return nil, "prompt_cache_options must be an object" end
	if options.mode ~= nil and options.mode ~= "implicit" and options.mode ~= "explicit" then
		return nil, "prompt_cache_options mode is invalid"
	end
	if options.ttl ~= nil and options.ttl ~= "30m" then
		return nil, "prompt_cache_options ttl is invalid"
	end
	for key in pairs(options) do
		if key ~= "mode" and key ~= "ttl" then
			return nil, "prompt_cache_options contains an unsupported field"
		end
	end
	local normalized = json.object()
	normalized.mode = options.mode
	normalized.ttl = options.ttl
	return normalized
end

---@param messages any
---@return boolean
local function normalizeMessages(messages)
	if not json.isArray(messages) or #messages == 0 then return false end
	---@type {id: string, name: string}?
	local pending_legacy_call
	for _, message in ipairs(messages) do
		if not json.isObject(message) then return false end
		local role = message.role
		if pending_legacy_call and role ~= "function" then return false end
		if role ~= "developer" and role ~= "system" and role ~= "user" and role ~= "assistant"
			and role ~= "tool" and role ~= "function"
		then
			return false
		end
		if role == "assistant" and message.function_call ~= nil then
			local function_call = message.function_call
			if message.tool_calls ~= nil or not json.isObject(function_call)
				or type(function_call.name) ~= "string" or function_call.name == ""
				or type(function_call.arguments) ~= "string"
			then
				return false
			end
			pending_legacy_call = {id = "legacy_call_" .. random.hex(12), name = function_call.name}
			message.tool_calls = json.array({{
				id = pending_legacy_call.id,
				type = "function",
				["function"] = {name = function_call.name, arguments = function_call.arguments},
			}})
			message.function_call = nil
		elseif role == "function" then
			if not pending_legacy_call or type(message.name) ~= "string"
				or message.name ~= pending_legacy_call.name
			then
				return false
			end
			message.role = "tool"
			message.tool_call_id = pending_legacy_call.id
			message.name = nil
			role = "tool"
			pending_legacy_call = nil
		end
		if message.content ~= nil and message.content ~= json.null then
			local content = normalizeContent(message.content, role)
			if content == nil then return false end
			message.content = content
		elseif role == "developer" or role == "system" or role == "user" or role == "tool" then
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

---@param value any
---@return boolean
local function isPositiveInteger(value)
	return type(value) == "number" and value >= 1 and value % 1 == 0
end

---@param value any
---@return boolean
local function isPresent(value)
	return value ~= nil and value ~= json.null
end

---@param request table
---@return boolean legacy_functions
---@return string?
local function normalizeLegacyFunctions(request)
	local has_functions = isPresent(request.functions)
	local has_function_call = isPresent(request.function_call)
	if not has_functions and not has_function_call then return false end
	if not has_functions then return false, "function_call requires functions" end
	if isPresent(request.tools) then return false, "functions and tools are mutually exclusive" end
	if isPresent(request.tool_choice) then return false, "function_call and tool_choice are mutually exclusive" end
	if not json.isArray(request.functions) then return false, "functions must be an array" end

	local tools = json.array()
	for _, schema in ipairs(request.functions) do
		table.insert(tools, {type = "function", ["function"] = schema})
	end
	if not validateTools(tools) then return false, "functions contain an invalid definition" end
	request.tools = tools
	if has_function_call then
		local function_call = request.function_call
		if function_call == "none" or function_call == "auto" then
			request.tool_choice = function_call
		elseif json.isObject(function_call) and type(function_call.name) == "string" and function_call.name ~= "" then
			request.tool_choice = json.object({
				type = "function",
				["function"] = json.object({name = function_call.name}),
			})
		else
			return false, "function_call has an unsupported shape"
		end
	end
	return true
end

---@param res web.Response
---@param name string
---@return integer status
local function sendUnsupportedParameter(res, name)
	sendError(res, 400, name .. " is not supported by the ChatGPT subscription backend",
		"invalid_request_error", "unsupported_parameter")
	return 400
end

---@param tool_choice any
---@param tools any
---@return "none"|"auto"|"required"|aqua.openai.ResponsesFunctionToolChoice?
---@return string?
local function normalizeToolChoice(tool_choice, tools)
	if tool_choice == nil then return end
	if tool_choice == "none" then return "none" end
	if tool_choice == "auto" or tool_choice == "required" then
		if not tools or #tools == 0 then return nil, "tool_choice requires tools" end
		return tool_choice
	end
	if not json.isObject(tool_choice) or tool_choice.type ~= "function"
		or not json.isObject(tool_choice["function"])
		or type(tool_choice["function"].name) ~= "string" or tool_choice["function"].name == ""
	then
		return nil, "tool_choice has an unsupported shape"
	end
	if not tools or #tools == 0 then return nil, "tool_choice requires tools" end
	local name = tool_choice["function"].name
	for _, tool in ipairs(tools) do
		if tool["function"].name == name then return {type = "function", name = name} end
	end
	return nil, "tool_choice names an unavailable function"
end

---@param response_format any
---@return aqua.openai.ResponsesTextFormat?
---@return string?
local function normalizeResponseFormat(response_format)
	if response_format == nil then return end
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
	if schema.description ~= nil and type(schema.description) ~= "string" then
		return nil, "response_format json_schema description is invalid"
	end
	if schema.strict ~= nil and type(schema.strict) ~= "boolean" then
		return nil, "response_format json_schema strict is invalid"
	end
	return {
		type = "json_schema",
		name = schema.name,
		description = schema.description,
		schema = schema.schema,
		strict = schema.strict,
	}
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
	if isPresent(request.previous_response_id) or isPresent(request.conversation) then
		return "server-managed response state is not supported", "unsupported_response_state"
	end
	if request.reasoning ~= nil and request.reasoning ~= json.null then
		if not json.isObject(request.reasoning) then
			return "reasoning must be an object", "invalid_reasoning"
		end
		if request.reasoning.effort ~= nil and request.reasoning.effort ~= json.null
			and not reasoning_efforts[request.reasoning.effort]
		then
			return "reasoning effort is invalid", "invalid_reasoning"
		end
	end
	if request.text ~= nil and request.text ~= json.null and not json.isObject(request.text) then
		return "text must be an object", "invalid_text"
	end
	if request.include ~= nil and request.include ~= json.null then
		if not json.isArray(request.include) then return "include must be an array", "invalid_include" end
		for _, value in ipairs(request.include) do
			if type(value) ~= "string" then return "include values must be strings", "invalid_include" end
		end
	end
	if request.tools ~= nil and request.tools ~= json.null and not json.isArray(request.tools) then
		return "tools must be an array", "invalid_tools"
	end
	if request.parallel_tool_calls ~= nil and type(request.parallel_tool_calls) ~= "boolean" then
		return "parallel_tool_calls must be a boolean", "invalid_parallel_tool_calls"
	end
end

---@param res web.Response
---@param request table
---@return integer status
function ProxyServer:responses(res, request)
	local validation_err, validation_code = validateResponsesRequest(request, self.models_set)
	if validation_err then
		sendError(res, 400, validation_err, "invalid_request_error", assert(validation_code))
		return 400
	end

	local reasoning_effort = type(request.reasoning) == "table" and request.reasoning.effort or nil
	local verbosity = type(request.text) == "table" and request.text.verbosity or nil
	local client = self.create_client(request.model, reasoning_effort, {
		parallel_tool_calls = request.parallel_tool_calls,
		verbosity = verbosity,
	})
	if request.stream ~= true then
		local response, _, provider_error = client:createResponse(request)
		if not response then
			if provider_error then return sendProviderError(res, provider_error) end
			sendError(res, 502, "upstream request failed", "upstream_error", "upstream_error")
			return 502
		end
		sendJson(res, response)
		return 200
	end

	local started = false
	local response, _, provider_error = client:createResponse(request, function(event)
		if not started then
			started = true
			startEventStream(res)
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
		startEventStream(res)
	end
	res:send("")
	return 200
end

---@param res web.Response
---@param request table
---@return integer status
function ProxyServer:complete(res, request)
	local legacy_functions, legacy_functions_err = normalizeLegacyFunctions(request)
	if type(request.model) ~= "string" or not self.models_set[request.model] then
		sendError(res, 400, "model is not available", "invalid_request_error", "model_not_found")
		return 400
	elseif legacy_functions_err then
		sendError(res, 400, legacy_functions_err, "invalid_request_error", "invalid_functions")
		return 400
	elseif not normalizeMessages(request.messages) then
		sendError(res, 400, "messages have an unsupported shape", "invalid_request_error", "invalid_messages")
		return 400
	elseif not validateTools(request.tools) then
		sendError(res, 400, "tools must be an array", "invalid_request_error", "invalid_tools")
		return 400
	elseif request.stream ~= nil and type(request.stream) ~= "boolean" then
		sendError(res, 400, "stream must be a boolean", "invalid_request_error", "invalid_stream")
		return 400
	elseif request.stream_options ~= nil and (not request.stream or not json.isObject(request.stream_options)
		or (request.stream_options.include_usage ~= nil and type(request.stream_options.include_usage) ~= "boolean"))
	then
		sendError(res, 400, "stream_options requires stream=true and a boolean include_usage", "invalid_request_error", "invalid_stream_options")
		return 400
	elseif request.reasoning_effort ~= nil and not reasoning_efforts[request.reasoning_effort] then
		sendError(res, 400, "reasoning_effort is invalid", "invalid_request_error", "invalid_reasoning_effort")
		return 400
	elseif request.parallel_tool_calls ~= nil and type(request.parallel_tool_calls) ~= "boolean" then
		sendError(res, 400, "parallel_tool_calls must be a boolean", "invalid_request_error", "invalid_parallel_tool_calls")
		return 400
	elseif legacy_functions and request.parallel_tool_calls == true then
		sendError(res, 400, "legacy functions do not support parallel_tool_calls",
			"invalid_request_error", "invalid_parallel_tool_calls")
		return 400
	elseif request.verbosity ~= nil and not verbosities[request.verbosity] then
		sendError(res, 400, "verbosity is invalid", "invalid_request_error", "invalid_verbosity")
		return 400
	end
	if isPresent(request.temperature)
		and (type(request.temperature) ~= "number" or request.temperature < 0 or request.temperature > 2)
	then
		sendError(res, 400, "temperature must be between 0 and 2", "invalid_request_error", "invalid_temperature")
		return 400
	end
	if isPresent(request.temperature) and request.temperature ~= 1 then
		return sendUnsupportedParameter(res, "temperature values other than 1")
	end
	if isPresent(request.top_p)
		and (type(request.top_p) ~= "number" or request.top_p < 0 or request.top_p > 1)
	then
		sendError(res, 400, "top_p must be between 0 and 1", "invalid_request_error", "invalid_top_p")
		return 400
	end
	if isPresent(request.top_p) and request.top_p ~= 1 then
		return sendUnsupportedParameter(res, "top_p values other than 1")
	end
	if isPresent(request.n) then
		if not isPositiveInteger(request.n) then
			sendError(res, 400, "n must be a positive integer", "invalid_request_error", "invalid_n")
			return 400
		elseif request.n ~= 1 then
			return sendUnsupportedParameter(res, "n values other than 1")
		end
	end
	if isPresent(request.stop) and not (json.isArray(request.stop) and #request.stop == 0) then
		return sendUnsupportedParameter(res, "stop")
	end
	if isPresent(request.seed) then return sendUnsupportedParameter(res, "seed") end
	if request.logprobs ~= nil and request.logprobs ~= json.null and request.logprobs ~= false then
		if request.logprobs ~= true then
			sendError(res, 400, "logprobs must be a boolean", "invalid_request_error", "invalid_logprobs")
			return 400
		end
		return sendUnsupportedParameter(res, "logprobs")
	end
	if isPresent(request.top_logprobs) then return sendUnsupportedParameter(res, "top_logprobs") end
	for _, name in ipairs({"frequency_penalty", "presence_penalty"}) do
		local value = request[name]
		if isPresent(value) then
			if type(value) ~= "number" or value < -2 or value > 2 then
				sendError(res, 400, name .. " must be between -2 and 2", "invalid_request_error", "invalid_" .. name)
				return 400
			elseif value ~= 0 then
				return sendUnsupportedParameter(res, name)
			end
		end
	end
	if isPresent(request.logit_bias) then
		if not json.isObject(request.logit_bias) then
			sendError(res, 400, "logit_bias must be an object", "invalid_request_error", "invalid_logit_bias")
			return 400
		end
		if next(request.logit_bias) then return sendUnsupportedParameter(res, "logit_bias") end
	end
	if request.max_completion_tokens ~= nil and request.max_tokens ~= nil then
		sendError(res, 400, "max_completion_tokens and max_tokens are mutually exclusive", "invalid_request_error", "invalid_max_tokens")
		return 400
	end
	local max_output_tokens = request.max_completion_tokens or request.max_tokens
	if max_output_tokens ~= nil and not isPositiveInteger(max_output_tokens) then
		sendError(res, 400, "completion token limit must be a positive integer", "invalid_request_error", "invalid_max_tokens")
		return 400
	end
	-- The ChatGPT Codex backend rejects Responses max_output_tokens. Accept the
	-- Chat Completions limit for client compatibility and retain the model cap.
	if request.prompt_cache_key ~= nil and (type(request.prompt_cache_key) ~= "string"
		or request.prompt_cache_key == "" or #request.prompt_cache_key > 64)
	then
		sendError(res, 400, "prompt_cache_key must contain 1 to 64 bytes", "invalid_request_error", "invalid_prompt_cache_key")
		return 400
	end
	local prompt_cache_options, prompt_cache_options_err = normalizePromptCacheOptions(request.prompt_cache_options)
	if prompt_cache_options_err then
		sendError(res, 400, prompt_cache_options_err, "invalid_request_error", "invalid_prompt_cache_options")
		return 400
	end
	local tool_choice, tool_choice_err = normalizeToolChoice(request.tool_choice, request.tools)
	if tool_choice_err then
		sendError(res, 400, tool_choice_err, "invalid_request_error", "invalid_tool_choice")
		return 400
	end
	local text_format, response_format_err = normalizeResponseFormat(request.response_format)
	if response_format_err then
		sendError(res, 400, response_format_err, "invalid_request_error", "invalid_response_format")
		return 400
	end

	local client = self.create_client(request.model, request.reasoning_effort, {
		prompt_cache_key = request.prompt_cache_key,
		prompt_cache_options = prompt_cache_options,
		tool_choice = tool_choice,
		parallel_tool_calls = not legacy_functions and request.parallel_tool_calls ~= false,
		verbosity = request.verbosity,
		text_format = text_format,
	})
	local completion_id = "chatcmpl-" .. random.hex(16)
	local created = os.time()
	local include_usage = request.stream_options and request.stream_options.include_usage == true or false
	if not request.stream then
		local message, _, provider_error = client:completeStream(request.messages, request.tools)
		if not message then
			if provider_error then
				return sendProviderError(res, provider_error)
			end
			sendError(res, 502, "upstream request failed", "upstream_error", "upstream_error")
			return 502
		end
		sendJson(res, createCompletion(request.model, message, completion_id, created, legacy_functions))
		return 200
	end

	local started = false
	local streamed_tool_calls = false
	local function ensureStarted()
		if started then return end
		started = true
		startEventStream(res)
		sendChunk(res, request.model, completion_id, created, {role = "assistant"}, nil, include_usage)
	end
	local message, _, provider_error = client:completeStream(request.messages, request.tools, function(content)
		ensureStarted()
		sendChunk(res, request.model, completion_id, created, {content = content}, nil, include_usage)
	end, function(content)
		ensureStarted()
		sendChunk(res, request.model, completion_id, created, {reasoning_content = content}, nil, include_usage)
	end, function(delta)
		ensureStarted()
		streamed_tool_calls = true
		if legacy_functions then
			sendChunk(res, request.model, completion_id, created, {function_call = {
				name = delta.name,
				arguments = delta.arguments,
			}}, nil, include_usage)
			return
		end
		local tool_call = {index = delta.index}
		if delta.id then
			tool_call.id = delta.id
			tool_call.type = "function"
		end
		if delta.name or delta.arguments then
			tool_call["function"] = {name = delta.name, arguments = delta.arguments}
		end
		sendChunk(res, request.model, completion_id, created, {tool_calls = {tool_call}}, nil, include_usage)
	end)
	if not message then
		if not started then
			if provider_error then
				return sendProviderError(res, provider_error)
			end
			sendError(res, 502, "upstream request failed", "upstream_error", "upstream_error")
			return 502
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
	ensureStarted()
	if message.tool_calls and not streamed_tool_calls then
		if legacy_functions then
			sendChunk(res, request.model, completion_id, created,
				{function_call = message.tool_calls[1]["function"]}, nil, include_usage)
		else
			local tool_calls = {}
			for index, tool_call in ipairs(message.tool_calls) do
				tool_calls[index] = {
					index = index - 1,
					id = tool_call.id,
					type = "function",
					["function"] = tool_call["function"],
				}
			end
			sendChunk(res, request.model, completion_id, created, {tool_calls = tool_calls}, nil, include_usage)
		end
	end
	sendChunk(res, request.model, completion_id, created, json.object(),
		getFinishReason(message, legacy_functions), include_usage)
	if include_usage and message.usage then
		sendUsageChunk(res, request.model, completion_id, created, message.usage)
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

---@param req web.Request
---@param res web.Response
---@param path string
---@return integer status
function ProxyServer:handleAuthenticated(req, res, path)
	if req.method == "GET" and path == "/v1/models" then
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
		local request, decode_err = body and json.decode_safe(body) or nil
		if type(request) ~= "table" then
			sendError(res, 400, "invalid JSON body: " .. tostring(decode_err or receive_err), "invalid_request_error", "invalid_json")
			return 400
		end
		if path == "/v1/responses" then return self:responses(res, request) end
		return self:complete(res, request)
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
	local status
	local path = req.uri:match("^[^?]+") or req.uri
	if not user then
		sendError(res, 401, "invalid access token", "authentication_error", "invalid_api_key")
		status = 401
	elseif not self:consumeRateLimit(assert(token)) then
		res.headers:set("Retry-After", 60)
		sendError(res, 429, "rate limit exceeded", "rate_limit_error", "rate_limit_exceeded")
		status = 429
	elseif not self:acquireRequest(token) then
		res.headers:set("Retry-After", 1)
		sendError(res, 429, "too many concurrent requests", "rate_limit_error", "concurrency_limit_exceeded")
		status = 429
	else
		local handle_err
		local ok = xpcall(function()
			status = self:handleAuthenticated(req, res, path)
		end, function(err)
			handle_err = debug.traceback(err, 2)
		end)
		self:releaseRequest(token)
		if not ok then error(handle_err, 0) end
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
