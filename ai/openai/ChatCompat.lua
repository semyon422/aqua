local json = require("web.json")
local random = require("web.random")

-- Pure Chat Completions compatibility translation for the ChatGPT Codex
-- subscription backend: request validation and normalization into Responses
-- client options, assistant result shaping, and streaming delta construction.
-- Shared by ai.openai.ProxyServer and the ai.router OpenAI subscription
-- provider; nothing here touches sockets, responses, or server state.
---@class openai.ChatCompat
local ChatCompat = {}

ChatCompat.reasoning_efforts = {
	none = true,
	minimal = true,
	low = true,
	medium = true,
	high = true,
	xhigh = true,
	max = true,
}

ChatCompat.verbosities = {
	low = true,
	medium = true,
	high = true,
}

---@param value any
---@return boolean
function ChatCompat.isPresent(value)
	return value ~= nil and value ~= json.null
end

---@param value any
---@return boolean
function ChatCompat.isPositiveInteger(value)
	return type(value) == "number" and value >= 1 and value % 1 == 0
end

---@param role string
---@return string|table[]?
local function normalizeContent(content, role)
	if type(content) == "string" then return content end
	if not json.isArray(content) then return end
	---@type string[]
	local text_parts = {}
	---@type table[]
	local input_parts = {}
	local has_non_text = false
	local has_breakpoint = false
	---@cast content openai.ContentPart[]
	for _, part in ipairs(content) do
		if not json.isObject(part) then return end
		---@cast part openai.ContentPart
		---@type {mode: "explicit"}?
		local breakpoint
		if part.prompt_cache_breakpoint ~= nil then
			if not json.isObject(part.prompt_cache_breakpoint)
				or part.prompt_cache_breakpoint.mode ~= "explicit"
			then
				return
			end
			---@diagnostic disable-next-line: no-unknown
			for key in pairs(part.prompt_cache_breakpoint) do
				---@cast key string
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
---@return openai.PromptCacheOptions?
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
	-- LuaLS 3.19 does not infer keys from validated dynamic objects.
	---@diagnostic disable-next-line: no-unknown
	for key in pairs(options) do
		---@cast key string
		if key ~= "mode" and key ~= "ttl" then
			return nil, "prompt_cache_options contains an unsupported field"
		end
	end
	---@type openai.PromptCacheOptions
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
	---@cast messages openai.UntrustedMessage[]
	for _, message in ipairs(messages) do
		if not json.isObject(message) then return false end
		---@cast message openai.UntrustedMessage
		local role = message.role
		if pending_legacy_call and role ~= "function" then return false end
		if role ~= "developer" and role ~= "system" and role ~= "user" and role ~= "assistant"
			and role ~= "tool" and role ~= "function"
		then
			return false
		end
		if role == "assistant" and message.function_call ~= nil then
			---@type openai.UntrustedFunctionCall
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
		---@type openai.ToolCall[]
		local tool_calls = message.tool_calls or {}
		for _, tool_call in ipairs(tool_calls) do
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
	---@cast tools openai.ToolSchema[]
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

---@param request table
---@return boolean legacy_functions
---@return string?
local function normalizeLegacyFunctions(request)
	local has_functions = ChatCompat.isPresent(request.functions)
	local has_function_call = ChatCompat.isPresent(request.function_call)
	if not has_functions and not has_function_call then return false end
	if not has_functions then return false, "function_call requires functions" end
	if ChatCompat.isPresent(request.tools) then return false, "functions and tools are mutually exclusive" end
	if ChatCompat.isPresent(request.tool_choice) then return false, "function_call and tool_choice are mutually exclusive" end
	if not json.isArray(request.functions) then return false, "functions must be an array" end

	---@type openai.ToolSchema[]
	local tools = json.array()
	---@type openai.FunctionSchema[]
	local functions = request.functions
	for _, schema in ipairs(functions) do
		table.insert(tools, {type = "function", ["function"] = schema})
	end
	if not validateTools(tools) then return false, "functions contain an invalid definition" end
	request.tools = tools
	if has_function_call then
		---@type openai.UntrustedFunctionCall|string
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

---@param tool_choice any
---@param tools openai.ToolSchema[]?
---@return "none"|"auto"|"required"|openai.ResponsesFunctionToolChoice?
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
	---@type string
	local name = tool_choice["function"].name
	for _, tool in ipairs(tools) do
		if tool["function"].name == name then return {type = "function", name = name} end
	end
	return nil, "tool_choice names an unavailable function"
end

---@param response_format any
---@return openai.ResponsesTextFormat?
---@return string?
local function normalizeResponseFormat(response_format)
	if response_format == nil then return end
	if not json.isObject(response_format) then return nil, "response_format must be an object" end
	if response_format.type == "text" or response_format.type == "json_object" then
		---@type "text"|"json_object"
		local format_type = response_format.type
		return {type = format_type}
	end
	if response_format.type ~= "json_schema" or not json.isObject(response_format.json_schema) then
		return nil, "response_format has an unsupported shape"
	end
	---@type {name: any?, description: any?, schema: any?, strict: any?}
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

---@class openai.ChatCompatRequest
---@field legacy_functions boolean
---@field messages openai.Message[]
---@field tools openai.ToolSchema[]?
---@field stream boolean
---@field include_usage boolean
---@field reasoning_effort openai.ReasoningEffort?
---@field client_options openai.ProxyRequestOptions

---@param name string
---@return nil
---@return string message
---@return string code
local function unsupported(name)
	return nil, name .. " is not supported by the ChatGPT subscription backend", "unsupported_parameter"
end

-- Validates a Chat Completions request against the subscription backend's
-- capabilities and normalizes it into client options. The request model name
-- and its allowlisting are the caller's responsibility; unknown fields keep
-- their Chat Completions passthrough behavior elsewhere. On failure returns
-- nil, a human-readable message, and an error code.
---@param request table
---@return openai.ChatCompatRequest? compat
---@return string? message
---@return string? code
function ChatCompat.normalizeRequest(request)
	local legacy_functions, legacy_functions_err = normalizeLegacyFunctions(request)
	if legacy_functions_err then
		return nil, legacy_functions_err, "invalid_functions"
	elseif not normalizeMessages(request.messages) then
		return nil, "messages have an unsupported shape", "invalid_messages"
	elseif not validateTools(request.tools) then
		return nil, "tools must be an array", "invalid_tools"
	elseif request.stream ~= nil and type(request.stream) ~= "boolean" then
		return nil, "stream must be a boolean", "invalid_stream"
	elseif request.stream_options ~= nil and (not request.stream or not json.isObject(request.stream_options)
			or (request.stream_options.include_usage ~= nil and type(request.stream_options.include_usage) ~= "boolean"))
	then
		return nil, "stream_options requires stream=true and a boolean include_usage", "invalid_stream_options"
	elseif request.reasoning_effort ~= nil and not ChatCompat.reasoning_efforts[request.reasoning_effort] then
		return nil, "reasoning_effort is invalid", "invalid_reasoning_effort"
	elseif request.parallel_tool_calls ~= nil and type(request.parallel_tool_calls) ~= "boolean" then
		return nil, "parallel_tool_calls must be a boolean", "invalid_parallel_tool_calls"
	elseif legacy_functions and request.parallel_tool_calls == true then
		return nil, "legacy functions do not support parallel_tool_calls", "invalid_parallel_tool_calls"
	elseif request.verbosity ~= nil and not ChatCompat.verbosities[request.verbosity] then
		return nil, "verbosity is invalid", "invalid_verbosity"
	end
	if ChatCompat.isPresent(request.temperature)
		and (type(request.temperature) ~= "number" or request.temperature < 0 or request.temperature > 2)
	then
		return nil, "temperature must be between 0 and 2", "invalid_temperature"
	end
	if ChatCompat.isPresent(request.temperature) and request.temperature ~= 1 then
		return unsupported("temperature values other than 1")
	end
	if ChatCompat.isPresent(request.top_p)
		and (type(request.top_p) ~= "number" or request.top_p < 0 or request.top_p > 1)
	then
		return nil, "top_p must be between 0 and 1", "invalid_top_p"
	end
	if ChatCompat.isPresent(request.top_p) and request.top_p ~= 1 then
		return unsupported("top_p values other than 1")
	end
	if ChatCompat.isPresent(request.n) then
		if not ChatCompat.isPositiveInteger(request.n) then
			return nil, "n must be a positive integer", "invalid_n"
		elseif request.n ~= 1 then
			return unsupported("n values other than 1")
		end
	end
	if ChatCompat.isPresent(request.stop) and not (json.isArray(request.stop) and #request.stop == 0) then
		return unsupported("stop")
	end
	if ChatCompat.isPresent(request.seed) then return unsupported("seed") end
	if request.logprobs ~= nil and request.logprobs ~= json.null and request.logprobs ~= false then
		if request.logprobs ~= true then
			return nil, "logprobs must be a boolean", "invalid_logprobs"
		end
		return unsupported("logprobs")
	end
	if ChatCompat.isPresent(request.top_logprobs) then return unsupported("top_logprobs") end
	---@type string[]
	local penalty_names = {"frequency_penalty", "presence_penalty"}
	for _, name in ipairs(penalty_names) do
		---@type any
		local value = request[name]
		if ChatCompat.isPresent(value) then
			if type(value) ~= "number" or value < -2 or value > 2 then
				return nil, name .. " must be between -2 and 2", "invalid_" .. name
			elseif value ~= 0 then
				return unsupported(name)
			end
		end
	end
	if ChatCompat.isPresent(request.logit_bias) then
		if not json.isObject(request.logit_bias) then
			return nil, "logit_bias must be an object", "invalid_logit_bias"
		end
		if next(request.logit_bias) then return unsupported("logit_bias") end
	end
	if request.max_completion_tokens ~= nil and request.max_tokens ~= nil then
		return nil, "max_completion_tokens and max_tokens are mutually exclusive", "invalid_max_tokens"
	end
	---@type integer?
	local max_output_tokens = request.max_completion_tokens or request.max_tokens
	if max_output_tokens ~= nil and not ChatCompat.isPositiveInteger(max_output_tokens) then
		return nil, "completion token limit must be a positive integer", "invalid_max_tokens"
	end
	-- The ChatGPT Codex backend rejects Responses max_output_tokens. Accept the
	-- Chat Completions limit for client compatibility and retain the model cap.
	if request.prompt_cache_key ~= nil and (type(request.prompt_cache_key) ~= "string"
			or request.prompt_cache_key == "" or #request.prompt_cache_key > 64)
	then
		return nil, "prompt_cache_key must contain 1 to 64 bytes", "invalid_prompt_cache_key"
	end
	local prompt_cache_options, prompt_cache_options_err = normalizePromptCacheOptions(request.prompt_cache_options)
	if prompt_cache_options_err then
		return nil, prompt_cache_options_err, "invalid_prompt_cache_options"
	end
	local tool_choice, tool_choice_err = normalizeToolChoice(request.tool_choice, request.tools)
	if tool_choice_err then
		return nil, tool_choice_err, "invalid_tool_choice"
	end
	local text_format, response_format_err = normalizeResponseFormat(request.response_format)
	if response_format_err then
		return nil, response_format_err, "invalid_response_format"
	end

	---@type openai.ChatCompatRequest
	return {
		legacy_functions = legacy_functions,
		messages = request.messages,
		tools = request.tools,
		stream = request.stream == true,
		include_usage = request.stream_options and request.stream_options.include_usage == true or false,
		reasoning_effort = request.reasoning_effort,
		client_options = {
			prompt_cache_key = request.prompt_cache_key,
			prompt_cache_options = prompt_cache_options,
			tool_choice = tool_choice,
			parallel_tool_calls = not legacy_functions and request.parallel_tool_calls ~= false,
			verbosity = request.verbosity,
			text_format = text_format,
		},
	}
end

---@param usage openai.TokenUsage
---@return table
function ChatCompat.createCompletionUsage(usage)
	return {
		prompt_tokens = usage.input_tokens,
		completion_tokens = usage.output_tokens,
		total_tokens = usage.total_tokens,
		prompt_tokens_details = usage.input_tokens_details,
		completion_tokens_details = usage.output_tokens_details,
	}
end

---@param message openai.Message
---@param legacy_functions boolean
---@return "stop"|"length"|"tool_calls"|"content_filter"|"function_call"
function ChatCompat.getFinishReason(message, legacy_functions)
	local finish_reason = message.finish_reason or (message.tool_calls and "tool_calls" or "stop")
	if legacy_functions and finish_reason == "tool_calls" then return "function_call" end
	return finish_reason
end

---@param model string
---@param message openai.Message
---@param completion_id string
---@param created integer
---@param legacy_functions boolean
---@return table
function ChatCompat.createCompletion(model, message, completion_id, created, legacy_functions)
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
			finish_reason = ChatCompat.getFinishReason(message, legacy_functions),
		}},
	}
	if message.usage then completion.usage = ChatCompat.createCompletionUsage(message.usage) end
	return completion
end

-- Builds the Chat Completions delta table for one streamed tool-call event.
---@param delta openai.ToolCallDelta
---@param legacy_functions boolean
---@return table
function ChatCompat.toolCallDelta(delta, legacy_functions)
	if legacy_functions then
		return {function_call = {
			name = delta.name,
			arguments = delta.arguments,
		}}
	end
	local tool_call = {index = delta.index}
	if delta.id then
		tool_call.id = delta.id
		tool_call.type = "function"
	end
	if delta.name or delta.arguments then
		tool_call["function"] = {name = delta.name, arguments = delta.arguments}
	end
	return {tool_calls = {tool_call}}
end

-- Builds the delta table for tool calls that arrived without incremental
-- events, or nil when the message has none.
---@param message openai.Message
---@param legacy_functions boolean
---@return table? delta
function ChatCompat.terminalToolCalls(message, legacy_functions)
	if not message.tool_calls then return nil end
	if legacy_functions then
		return {function_call = message.tool_calls[1]["function"]}
	end
	---@type table[]
	local tool_calls = {}
	for index, tool_call in ipairs(message.tool_calls) do
		tool_calls[index] = {
			index = index - 1,
			id = tool_call.id,
			type = "function",
			["function"] = tool_call["function"],
		}
	end
	return {tool_calls = tool_calls}
end

return ChatCompat
