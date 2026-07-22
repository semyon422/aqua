local class = require("class")
local json = require("web.json")
local random = require("web.random")
local SseParser = require("ai.openai.SseParser")

---@alias aqua.openai.ReasoningEffort "none"|"minimal"|"low"|"medium"|"high"|"xhigh"|"max"

---@class aqua.openai.ResponsesFunctionToolChoice
---@field type "function"
---@field name string

---@class aqua.openai.ResponsesTextFormat
---@field type "text"|"json_object"|"json_schema"
---@field name string?
---@field description string?
---@field schema table?
---@field strict boolean?

---@class aqua.openai.ToolCallDelta
---@field index integer
---@field id string?
---@field name string?
---@field arguments string?

---@class aqua.openai.ProviderError
---@field status integer
---@field message string
---@field type string
---@field code string
---@field request_id string

---@class aqua.openai.SubscriptionClientOptions
---@field auth aqua.openai.SubscriptionAuth
---@field model string
---@field reasoning_effort aqua.openai.ReasoningEffort
---@field prompt_cache_key string?
---@field tool_choice "none"|"auto"|"required"|aqua.openai.ResponsesFunctionToolChoice?
---@field parallel_tool_calls boolean?
---@field verbosity "low"|"medium"|"high"?
---@field text_format aqua.openai.ResponsesTextFormat?
---@field max_response_size integer?
---@field timeout number?
---@field open_stream aqua.openai.OpenStreamFunc

---@class aqua.openai.SubscriptionClient
---@operator call: aqua.openai.SubscriptionClient
---@field auth aqua.openai.SubscriptionAuth
---@field model string
---@field reasoning_effort aqua.openai.ReasoningEffort
---@field prompt_cache_key string?
---@field tool_choice "none"|"auto"|"required"|aqua.openai.ResponsesFunctionToolChoice?
---@field parallel_tool_calls boolean?
---@field verbosity "low"|"medium"|"high"?
---@field text_format aqua.openai.ResponsesTextFormat?
---@field max_response_size integer
---@field timeout number?
---@field open_stream aqua.openai.OpenStreamFunc
---@field active_stream web.HttpStream?
---@field cancel_requested boolean
---@field session_id string
local SubscriptionClient = class()

SubscriptionClient.responses_url = "https://chatgpt.com/backend-api/codex/responses"
SubscriptionClient.max_response_size = 4 * 1024 * 1024

---@param options aqua.openai.SubscriptionClientOptions
function SubscriptionClient:new(options)
	assert(options.model ~= "", "model is required")
	self.auth = assert(options.auth, "auth is required")
	self.model = options.model
	self.reasoning_effort = options.reasoning_effort
	self.prompt_cache_key = options.prompt_cache_key
	self.tool_choice = options.tool_choice
	self.parallel_tool_calls = options.parallel_tool_calls
	self.verbosity = options.verbosity
	self.text_format = options.text_format
	self.max_response_size = options.max_response_size or self.max_response_size
	assert(self.max_response_size >= 1, "max_response_size must be positive")
	self.timeout = options.timeout
	self.open_stream = assert(options.open_stream, "open_stream is required")
	self.cancel_requested = false
	self.session_id = random.hex(16)
end

---@param messages aqua.openai.Message[]
---@return string
local function getInstructions(messages)
	local instructions = {}
	for _, message in ipairs(messages) do
		if (message.role == "developer" or message.role == "system") and type(message.content) == "string" then
			table.insert(instructions, message.content)
		end
	end
	return table.concat(instructions, "\n\n")
end

---@param messages aqua.openai.Message[]
---@return table[]
local function createInput(messages)
	local input = {}
	for _, message in ipairs(messages) do
		if message.role == "user" then
			local content = message.content
			if type(content) == "string" then
				content = {{type = "input_text", text = content}}
			end
			table.insert(input, {
				type = "message",
				role = "user",
				content = content or {},
			})
		elseif message.role == "assistant" then
			if message.response_items then
				for _, item in ipairs(message.response_items) do
					table.insert(input, item)
				end
			else
				if type(message.content) == "string" and message.content ~= "" then
					table.insert(input, {
						type = "message",
						role = "assistant",
						status = "completed",
						content = {{type = "output_text", text = message.content, annotations = {}}},
					})
				end
				for _, tool_call in ipairs(message.tool_calls or {}) do
					table.insert(input, {
						type = "function_call",
						call_id = tool_call.id,
						name = tool_call["function"].name,
						arguments = tool_call["function"].arguments,
					})
				end
			end
		elseif message.role == "tool" then
			table.insert(input, {
				type = "function_call_output",
				call_id = message.tool_call_id,
				output = message.content or "",
			})
		end
	end
	return input
end

---@param tools aqua.openai.ToolSchema[]?
---@return table[]?
local function createTools(tools)
	if not tools or #tools == 0 then return end
	local output = {}
	for _, tool in ipairs(tools) do
		local schema = tool["function"]
		table.insert(output, {
			type = "function",
			name = schema.name,
			description = schema.description,
			parameters = schema.parameters,
			strict = schema.strict,
		})
	end
	return output
end

---@param messages aqua.openai.Message[]
---@param tools aqua.openai.ToolSchema[]?
---@return table
function SubscriptionClient:createBody(messages, tools)
	local text = {verbosity = self.verbosity or "low"}
	if self.text_format then text.format = self.text_format end
	local body = {
		model = self.model,
		store = false,
		stream = true,
		instructions = getInstructions(messages),
		input = createInput(messages),
		include = {"reasoning.encrypted_content"},
		prompt_cache_key = self.prompt_cache_key,
		text = text,
		reasoning = {effort = self.reasoning_effort, summary = "auto"},
	}
	local response_tools = createTools(tools)
	if response_tools then
		body.tools = response_tools
		body.tool_choice = self.tool_choice or "auto"
		body.parallel_tool_calls = self.parallel_tool_calls
	elseif self.tool_choice == "none" then
		body.tool_choice = "none"
	end
	return body
end

---@param access_token string
---@param account_id string
---@return {[string]: string}
function SubscriptionClient:createHeaders(access_token, account_id)
	return {
		Authorization = "Bearer " .. access_token,
		["ChatGPT-Account-Id"] = account_id,
		["Content-Type"] = "application/json",
		Accept = "text/event-stream",
		["OpenAI-Beta"] = "responses=experimental",
		Originator = "soundsphere",
		["User-Agent"] = "soundsphere",
		session_id = self.session_id,
		["x-client-request-id"] = self.session_id,
	}
end

---@param value any
---@param fallback string
---@param max_length integer
---@return string
local function sanitizeErrorValue(value, fallback, max_length)
	if type(value) ~= "string" or value == "" then return fallback end
	value = value:gsub("[%c\127]", " "):gsub("%s+", " ")
	if #value > max_length then value = value:sub(1, max_length) end
	return value
end

---@param status integer
---@param body string?
---@param headers web.Headers?
---@param client_request_id string
---@return aqua.openai.ProviderError
local function createProviderError(status, body, headers, client_request_id)
	local decoded = body and json.decode_safe(body) or nil
	local provider = type(decoded) == "table" and decoded.error or nil
	if type(provider) ~= "table" then provider = {} end
	local request_id = headers and headers:get("x-request-id") or nil
	return {
		status = status,
		message = sanitizeErrorValue(provider.message, "upstream request failed", 512),
		type = sanitizeErrorValue(provider.type, "upstream_error", 128),
		code = sanitizeErrorValue(provider.code, "upstream_error", 128),
		request_id = sanitizeErrorValue(request_id, client_request_id, 512),
	}
end

---@param value any
---@return integer?
local function tokenCount(value)
	if type(value) ~= "number" or value < 0 or value % 1 ~= 0 then return end
	return value
end

---@param usage any
---@return aqua.openai.TokenUsage?
local function normalizeUsage(usage)
	if type(usage) ~= "table" then return end
	local input_tokens = tokenCount(usage.input_tokens)
	local output_tokens = tokenCount(usage.output_tokens)
	local total_tokens = tokenCount(usage.total_tokens)
	if not input_tokens or not output_tokens or not total_tokens then return end
	---@type aqua.openai.TokenUsage
	local normalized = {
		input_tokens = input_tokens,
		output_tokens = output_tokens,
		total_tokens = total_tokens,
	}
	if type(usage.input_tokens_details) == "table" then
		local cached_tokens = tokenCount(usage.input_tokens_details.cached_tokens)
		local audio_tokens = tokenCount(usage.input_tokens_details.audio_tokens)
		if cached_tokens or audio_tokens then
			normalized.input_tokens_details = {cached_tokens = cached_tokens, audio_tokens = audio_tokens}
		end
	end
	if type(usage.output_tokens_details) == "table" then
		local details = usage.output_tokens_details
		local reasoning_tokens = tokenCount(details.reasoning_tokens)
		local audio_tokens = tokenCount(details.audio_tokens)
		local accepted_prediction_tokens = tokenCount(details.accepted_prediction_tokens)
		local rejected_prediction_tokens = tokenCount(details.rejected_prediction_tokens)
		if reasoning_tokens or audio_tokens or accepted_prediction_tokens or rejected_prediction_tokens then
			normalized.output_tokens_details = {
				reasoning_tokens = reasoning_tokens,
				audio_tokens = audio_tokens,
				accepted_prediction_tokens = accepted_prediction_tokens,
				rejected_prediction_tokens = rejected_prediction_tokens,
			}
		end
	end
	return normalized
end

---@param items table[]
---@param usage aqua.openai.TokenUsage?
---@return aqua.openai.Message
local function createMessage(items, usage)
	---@type aqua.openai.Message
	local message = {role = "assistant", content = "", response_items = items, usage = usage}
	local text_parts = {}
	local reasoning_parts = {}
	local tool_calls = {}
	for _, item in ipairs(items) do
		if item.type == "message" and type(item.content) == "table" then
			for _, content in ipairs(item.content) do
				if content.type == "output_text" and type(content.text) == "string" then
					table.insert(text_parts, content.text)
				elseif content.type == "refusal" and type(content.refusal) == "string" then
					table.insert(text_parts, content.refusal)
				end
			end
		elseif item.type == "reasoning" and type(item.summary) == "table" then
			for _, summary in ipairs(item.summary) do
				if type(summary) == "table" and type(summary.text) == "string" then
					table.insert(reasoning_parts, summary.text)
				end
			end
		elseif item.type == "function_call" then
			table.insert(tool_calls, {
				id = item.call_id,
				type = "function",
				["function"] = {name = item.name, arguments = item.arguments or ""},
			})
		end
	end
	message.content = table.concat(text_parts)
	if #reasoning_parts > 0 then message.reasoning_content = table.concat(reasoning_parts) end
	if #tool_calls > 0 then message.tool_calls = tool_calls end
	return message
end

---@param messages aqua.openai.Message[]
---@param tools aqua.openai.ToolSchema[]?
---@param on_text_delta fun(content: string)?
---@param on_reasoning_delta fun(content: string)?
---@param on_tool_call_delta fun(delta: aqua.openai.ToolCallDelta)?
---@return aqua.openai.Message?
---@return string?
---@return aqua.openai.ProviderError?
function SubscriptionClient:completeStream(messages, tools, on_text_delta, on_reasoning_delta, on_tool_call_delta)
	local access_token, account_id, auth_err = self.auth:getAccess()
	if not access_token then return nil, auth_err or "OpenAI login is required" end
	if not account_id or account_id == "" then return nil, "OpenAI login has no account ID" end

	self.session_id = random.hex(16)
	self.cancel_requested = false
	local stream, err = self.open_stream(self.responses_url, {
		method = "POST",
		headers = self:createHeaders(access_token, account_id),
		timeout = self.timeout,
	})
	if not stream then return nil, err or "OpenAI subscription stream failed" end
	self.active_stream = stream
	if self.cancel_requested then
		stream:cancel("canceled")
		self.active_stream = nil
		return nil, "canceled"
	end

	local sent
	sent, err = stream:sendBody(json.encode(self:createBody(messages, tools)))
	if not sent then
		stream:close()
		self.active_stream = nil
		return nil, err
	end
	local headers_ok
	headers_ok, err = stream:receiveHeaders()
	if not headers_ok then
		stream:close()
		self.active_stream = nil
		return nil, err
	end
	local res = assert(stream.res)
	if res.status < 200 or res.status >= 300 then
		local error_body = stream:receiveBody()
		stream:close()
		self.active_stream = nil
		local provider_error = createProviderError(res.status, error_body, res.headers, self.session_id)
		return nil, ("OpenAI subscription returned HTTP %d: %s"):format(res.status, provider_error.message), provider_error
	end

	local done = false
	local parse_err
	local provider_error
	local received_size = 0
	local items = {}
	---@type {[integer]: integer}
	local tool_call_indexes = {}
	local next_tool_call_index = 0
	local usage
	---@param event table
	---@param item_type string
	---@return table
	local function getItem(event, item_type)
		local position = (tonumber(event.output_index) or #items) + 1
		local item = items[position]
		if not item then
			item = {type = item_type}
			items[position] = item
		end
		return item
	end
	---@param event table
	---@param content_type string
	---@return table
	local function getContent(event, content_type)
		local item = getItem(event, "message")
		item.role = item.role or "assistant"
		item.content = item.content or {}
		local position = (tonumber(event.content_index) or #item.content) + 1
		local content = item.content[position]
		if not content then
			content = {type = content_type}
			item.content[position] = content
		end
		return content
	end
	---@param event table
	---@return integer
	local function getToolCallIndex(event)
		local output_index = tonumber(event.output_index) or #items
		local index = tool_call_indexes[output_index]
		if index == nil then
			index = next_tool_call_index
			next_tool_call_index = next_tool_call_index + 1
			tool_call_indexes[output_index] = index
		end
		return index
	end
	local parser = SseParser(function(data)
		if data == "[DONE]" then
			done = true
			return
		end
		local event, decode_err = json.decode_safe(data)
		if type(event) ~= "table" then
			parse_err = "invalid Responses streaming JSON: " .. tostring(decode_err)
			return
		end
		if event.type == "response.output_item.added" and type(event.item) == "table" then
			items[(tonumber(event.output_index) or #items) + 1] = event.item
			if event.item.type == "function_call" and on_tool_call_delta then
				on_tool_call_delta({
					index = getToolCallIndex(event),
					id = event.item.call_id,
					name = event.item.name,
					arguments = type(event.item.arguments) == "string" and event.item.arguments or "",
				})
			end
		elseif event.type == "response.content_part.added" and type(event.part) == "table" then
			local item = getItem(event, "message")
			item.role = item.role or "assistant"
			item.content = item.content or {}
			item.content[(tonumber(event.content_index) or #item.content) + 1] = event.part
		elseif event.type == "response.output_text.delta" and type(event.delta) == "string" then
			local content = getContent(event, "output_text")
			content.text = (content.text or "") .. event.delta
			if on_text_delta then on_text_delta(event.delta) end
		elseif event.type == "response.output_text.done" and type(event.text) == "string" then
			getContent(event, "output_text").text = event.text
		elseif event.type == "response.refusal.delta" and type(event.delta) == "string" then
			local content = getContent(event, "refusal")
			content.refusal = (content.refusal or "") .. event.delta
			if on_text_delta then on_text_delta(event.delta) end
		elseif event.type == "response.refusal.done" and type(event.refusal) == "string" then
			getContent(event, "refusal").refusal = event.refusal
		elseif event.type == "response.reasoning_summary_text.delta" and type(event.delta) == "string" then
			if on_reasoning_delta then on_reasoning_delta(event.delta) end
		elseif event.type == "response.function_call_arguments.delta" and type(event.delta) == "string" then
			local item = getItem(event, "function_call")
			item.arguments = (item.arguments or "") .. event.delta
			if on_tool_call_delta then
				on_tool_call_delta({index = getToolCallIndex(event), arguments = event.delta})
			end
		elseif event.type == "response.function_call_arguments.done" and type(event.arguments) == "string" then
			getItem(event, "function_call").arguments = event.arguments
		elseif event.type == "response.output_item.done" and type(event.item) == "table" then
			items[(tonumber(event.output_index) or #items) + 1] = event.item
		elseif event.type == "response.completed" then
			if type(event.response) == "table" then
				if type(event.response.output) == "table" and #event.response.output > 0 then
					items = event.response.output
				end
				usage = normalizeUsage(event.response.usage)
			end
			done = true
		elseif event.type == "response.failed" or event.type == "response.incomplete" then
			local response_error = type(event.response) == "table" and event.response.error or nil
			parse_err = type(response_error) == "table" and tostring(response_error.message) or "OpenAI response failed"
			if type(response_error) == "table" then
				provider_error = createProviderError(502, json.encode({error = response_error}), res.headers, self.session_id)
			end
		elseif event.type == "error" then
			parse_err = tostring(event.message or (type(event.error) == "table" and event.error.message) or "OpenAI streaming error")
			local event_error = type(event.error) == "table" and event.error or event
			provider_error = createProviderError(502, json.encode({error = event_error}), res.headers, self.session_id)
		end
	end)

	while not done and not parse_err do
		local chunk
		chunk, err = stream:receiveChunk()
		if not chunk then break end
		received_size = received_size + #chunk
		if received_size > self.max_response_size then
			parse_err = "OpenAI subscription response is too large"
			break
		end
		parser:feed(chunk)
	end
	parser:finish()
	stream:close()
	self.active_stream = nil
	if parse_err then return nil, parse_err, provider_error end
	if not done then return nil, err or "Responses stream closed before completion" end
	local message = createMessage(items, usage)
	if message.content == "" and not message.tool_calls then
		return nil, "OpenAI response has neither text nor tool calls"
	end
	return message
end

---@return boolean
function SubscriptionClient:cancel()
	self.cancel_requested = true
	if self.active_stream then
		return self.active_stream:cancel("canceled")
	end
	return false
end

return SubscriptionClient
