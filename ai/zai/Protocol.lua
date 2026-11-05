local json = require("web.json")

-- Pure GLM Coding Plan request validation/normalization. No HTTP server,
-- authentication, scheduler or provider transport is required by this module.
local Protocol = {}

---@class zai.UntrustedObject
---@field [any] any

---@class zai.UntrustedFunctionCall: zai.UntrustedObject
---@field name any?
---@field arguments any?

---@class zai.UntrustedToolCall: zai.UntrustedObject
---@field id any?
---@field type any?
---@field ["function"] zai.UntrustedFunctionCall?

---@class zai.UntrustedMessage: zai.UntrustedObject
---@field role any?
---@field content any?
---@field tool_calls any?
---@field tool_call_id any?

---@class zai.UntrustedContentPart: zai.UntrustedObject
---@field type any?
---@field text any?

---@class zai.ToolSchema: zai.UntrustedObject
---@field type any?
---@field ["function"] zai.UntrustedFunctionCall?

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
	---@cast content zai.UntrustedContentPart[]
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
---@return zai.UntrustedMessage[]? normalized
function Protocol.normalizeMessages(messages)
	if not json.isArray(messages) or #messages == 0 then return end
	---@type zai.UntrustedMessage[]
	local normalized = {}
	for _, message in ipairs(messages) do
		if not json.isObject(message) then return end
		---@cast message zai.UntrustedMessage
		local role = message.role
		if role == "developer" then role = "system" end
		if role ~= "system" and role ~= "user" and role ~= "assistant" and role ~= "tool" then
			return
		end
		---@type zai.UntrustedMessage
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
			---@type zai.UntrustedToolCall[]
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
---@return zai.ToolSchema[]? normalized
function Protocol.normalizeTools(tools)
	if not isPresent(tools) then return {} end
	if not json.isArray(tools) then return end
	---@type zai.ToolSchema[]
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
---@param tools zai.ToolSchema[]
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
function Protocol.normalizeRequest(request, models_set, model_redirects, default_thinking, default_tool_stream)
	if type(request.model) ~= "string" or not models_set[request.model] then
		return nil, nil, false, false, "model is not available", "model_not_found"
	end
	local public_model = request.model
	local unsupported_err, unsupported_code = validateUnsupportedParameters(request)
	if unsupported_err then
		return nil, nil, false, false, unsupported_err, unsupported_code
	end
	local messages = Protocol.normalizeMessages(request.messages)
	if not messages then
		return nil, nil, false, false, "messages have an unsupported shape", "invalid_messages"
	end
	local tools = Protocol.normalizeTools(request.tools)
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

return Protocol
