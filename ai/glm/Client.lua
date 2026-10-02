local class = require("class")
local json = require("web.json")
local table_util = require("table_util")
local SseParser = require("ai.openai.SseParser")

---@alias glm.RequestFunc fun(url: string, body: table|string?, options: web.HttpRequestOptions?): {status: integer, headers: web.Headers?, body: string}?, string?
---@alias glm.OpenStreamFunc fun(url: string, options: web.HttpStreamOptions?): web.HttpStream?, string?

---@class glm.ProviderError
---@field status integer?
---@field message string
---@field type string
---@field code string
---@field request_id string?

---@class glm.ChatErrorBody
---@field message any?
---@field code any?
---@field type any?

---@class glm.ChatProviderResponse
---@field error glm.ChatErrorBody?
---@field choices glm.ChatProviderChoice[]?
---@field usage any?
---@field id any?
---@field created any?
---@field model any?
---@field request_id any?

---@class glm.ChatProviderChoice
---@field message any?
---@field delta any?
---@field finish_reason any?

---@class glm.ToolCallDeltaFunction
---@field name any?
---@field arguments any?

---@class glm.ToolCallDelta
---@field index any?
---@field id any?
---@field type any?
---@field ["function"] glm.ToolCallDeltaFunction?

---@class glm.MessageDelta
---@field content any?
---@field reasoning_content any?
---@field tool_calls glm.ToolCallDelta[]?

---@class glm.ToolCall
---@field id string
---@field type string
---@field ["function"] {name: string, arguments: string}

---@class glm.Message
---@field role string
---@field content string?
---@field reasoning_content string?
---@field tool_calls glm.ToolCall[]?
---@field finish_reason string?
---@field usage table?

---@class glm.ClientOptions
---@field base_url string
---@field api_key string
---@field timeout number?
---@field request glm.RequestFunc
---@field open_stream glm.OpenStreamFunc?

--- Sends chat completions to a GLM coding-plan endpoint. The endpoint speaks the
--- OpenAI Chat Completions protocol, including `reasoning_content` deltas and
--- `thinking` request fields.
---@class glm.Client
---@operator call: glm.Client
---@field base_url string
---@field api_key string
---@field timeout number?
---@field request glm.RequestFunc
---@field open_stream glm.OpenStreamFunc?
---@field active_stream web.HttpStream?
---@field cancel_requested boolean
local Client = class()

---@param options glm.ClientOptions
function Client:new(options)
	assert(type(options.base_url) == "string" and options.base_url ~= "", "base_url is required")
	assert(type(options.api_key) == "string" and options.api_key ~= "", "api_key is required")
	self.base_url = options.base_url:gsub("/$", "")
	self.api_key = options.api_key
	self.timeout = options.timeout
	self.request = assert(options.request, "request is required")
	self.open_stream = options.open_stream
	self.cancel_requested = false
end

---@return {[string]: string}
function Client:createHeaders()
	return {
		["Content-Type"] = "application/json",
		Accept = "application/json",
		Authorization = "Bearer " .. self.api_key,
	}
end

---@param res {status: integer, headers: web.Headers?}
---@param decoded table
---@return glm.ProviderError
local function providerError(res, decoded)
	local error_body = type(decoded.error) == "table" and decoded.error or {}
	local message = type(error_body.message) == "string" and error_body.message
		or ("GLM provider returned HTTP %d"):format(res.status)
	local code = type(error_body.code) == "string" and error_body.code or "upstream_error"
	local error_type = type(error_body.type) == "string" and error_body.type or "upstream_error"
	local request_id = res.headers and res.headers:get("x-request-id") or nil
	return {status = res.status, message = message, type = error_type, code = code, request_id = request_id}
end

---@param message any
---@return boolean
---@return string?
local function validateMessage(message)
	if type(message) ~= "table" or message.role ~= "assistant" then
		return false, "provider response is missing choices[1].message"
	end
	if message.content ~= nil and message.content ~= json.null and type(message.content) ~= "string" then
		return false, "assistant message content is not a string"
	end
	if message.content == nil and type(message.tool_calls) ~= "table" then
		return false, "assistant message has neither text nor tool calls"
	end
	return true
end

--- Sends a non-streaming completion. The body must not set `stream = true`;
--- the client sends `stream = false` explicitly.
---@param body table
---@return table? completion
---@return string? err
---@return glm.ProviderError? provider_error
function Client:complete(body)
	assert(body.stream ~= true, "streaming completion must use completeStream")
	local request_body = table_util.copy(body)
	request_body.stream = false
	local res, err = self.request(self.base_url .. "/chat/completions", json.encode(request_body), {
		method = "POST",
		headers = self:createHeaders(),
		timeout = self.timeout,
	})
	if not res then
		return nil, err or "GLM request failed"
	end
	local decoded, decode_err = json.decode_safe(res.body)
	if type(decoded) ~= "table" then
		return nil, "invalid provider JSON: " .. tostring(decode_err)
	end
	if res.status < 200 or res.status >= 300 then
		local provider_error = providerError(res, decoded)
		return nil, provider_error.message, provider_error
	end
	local choices = decoded.choices
	local choice = type(choices) == "table" and choices[1] or nil
	local message = type(choice) == "table" and choice.message or nil
	local valid, message_err = validateMessage(message)
	if not valid then
		return nil, message_err
	end
	return decoded
end

---@param message glm.Message
---@param delta glm.MessageDelta
function Client:applyDelta(message, delta)
	if type(delta.content) == "string" and delta.content ~= "" then
		message.content = (message.content or "") .. delta.content
	end
	if type(delta.reasoning_content) == "string" and delta.reasoning_content ~= "" then
		message.reasoning_content = (message.reasoning_content or "") .. delta.reasoning_content
	end
	if type(delta.tool_calls) ~= "table" then
		return
	end
	message.tool_calls = message.tool_calls or {}
	for _, tool_delta in ipairs(delta.tool_calls) do
		local index = tonumber(tool_delta.index) or 0
		local position = index + 1
		local tool_call = message.tool_calls[position]
		if not tool_call then
			tool_call = {
				id = "",
				type = "function",
				["function"] = {name = "", arguments = ""},
			}
			message.tool_calls[position] = tool_call
		end
		if type(tool_delta.id) == "string" then
			tool_call.id = tool_call.id .. tool_delta.id
		end
		local function_delta = tool_delta["function"]
		if type(function_delta) == "table" then
			if type(function_delta.name) == "string" then
				tool_call["function"].name = tool_call["function"].name .. function_delta.name
			end
			if type(function_delta.arguments) == "string" then
				tool_call["function"].arguments = tool_call["function"].arguments .. function_delta.arguments
			end
		end
	end
end

--- Sends a streaming completion and assembles one assistant message. Each
--- upstream delta is relayed to `on_delta`; returning false aborts the upstream
--- stream. The returned message carries the assembled `content`,
--- `reasoning_content`, `tool_calls`, the terminal `finish_reason`, and the
--- last reported `usage`.
---@param body table
---@param on_delta (fun(delta: glm.MessageDelta): boolean?)?
---@return glm.Message? message
---@return string? err
---@return glm.ProviderError? provider_error
function Client:completeStream(body, on_delta)
	local open_stream = assert(self.open_stream, "open_stream is required for streaming")
	self.cancel_requested = false
	local stream, err = open_stream(self.base_url .. "/chat/completions", {
		method = "POST",
		headers = self:createHeaders(),
		timeout = self.timeout,
	})
	if not stream then
		return nil, err or "GLM stream failed"
	end
	self.active_stream = stream
	if self.cancel_requested then
		stream:cancel("canceled")
		self.active_stream = nil
		return nil, "canceled"
	end

	local stream_body = table_util.copy(body)
	stream_body.stream = true
	local sent, err = stream:sendBody(json.encode(stream_body))
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
		local decoded = error_body and json.decode_safe(error_body) or nil
		if type(decoded) == "table" then
			local provider_error = providerError(res, decoded)
			return nil, provider_error.message, provider_error
		end
		return nil, ("GLM provider returned HTTP %d"):format(res.status)
	end

	---@type glm.Message
	local message = {role = "assistant", content = ""}
	local done = false
	---@type string?
	local parse_err
	local parser = SseParser(function(data)
		if data == "[DONE]" then
			done = true
			return
		end
		local event, decode_err = json.decode_safe(data)
		---@cast event glm.ChatProviderResponse?
		if type(event) ~= "table" then
			parse_err = "invalid streaming JSON: " .. tostring(decode_err)
			return
		end
		if type(event.error) == "table" then
			parse_err = tostring(event.error.message or "GLM streaming error")
			return
		end
		if type(event.usage) == "table" then
			message.usage = event.usage
		end
		local choice = type(event.choices) == "table" and event.choices[1] or nil
		if type(choice) ~= "table" then
			return
		end
		if type(choice.finish_reason) == "string" then
			message.finish_reason = choice.finish_reason
		end
		if type(choice.delta) == "table" then
			self:applyDelta(message, choice.delta)
			if on_delta and on_delta(choice.delta) == false and not parse_err then
				parse_err = "downstream response stream closed"
			end
		end
	end)

	while not done and not parse_err do
		local chunk
		chunk, err = stream:receiveAvailableChunk()
		if not chunk then
			break
		end
		parser:feed(chunk)
	end
	parser:finish()
	if parse_err == "downstream response stream closed" or err == "canceled" then
		stream:cancel(parse_err or err)
	else
		stream:close()
	end
	self.active_stream = nil
	if parse_err then
		return nil, parse_err
	end
	if not done then
		return nil, err or "stream closed before [DONE]"
	end
	if message.finish_reason == nil then
		message.finish_reason = message.tool_calls and "tool_calls" or "stop"
	end
	if message.content == "" and message.reasoning_content == nil
		and message.tool_calls == nil and message.usage == nil
	then
		return nil, "assistant message has neither text nor tool calls"
	end
	return message
end

---@return boolean
function Client:cancel()
	self.cancel_requested = true
	if self.active_stream then
		self.active_stream:cancel("canceled")
		return true
	end
	return false
end

return Client
