local class = require("class")
local json = require("web.json")
local table_util = require("table_util")
local SseParser = require("ai.openai.SseParser")
---@type {gettime: fun(): number}
local socket = require("socket")

---@alias openai.RequestFunc fun(url: string, body: table|string?, options: web.HttpRequestOptions?): {status: integer, headers: web.Headers?, body: string}?, string?
---@alias openai.OpenStreamFunc fun(url: string, options: web.HttpStreamOptions?): web.HttpStream?, string?

---@class openai.ChatCompletionsError
---@field status integer?
---@field message string
---@field type string
---@field code string
---@field request_id string?

---@class openai.ChatErrorBody
---@field message any?
---@field code any?
---@field type any?

---@class openai.ChatCompletionResponse
---@field error openai.ChatErrorBody?
---@field choices openai.ChatCompletionChoice[]?
---@field usage any?
---@field id any?
---@field created any?
---@field model any?
---@field request_id any?

---@class openai.ChatCompletionChoice
---@field message any?
---@field delta any?
---@field finish_reason any?

---@class openai.ChatFunctionDelta
---@field name any?
---@field arguments any?

---@class openai.ChatToolDelta
---@field index any?
---@field id any?
---@field type any?
---@field ["function"] openai.ChatFunctionDelta?

---@class openai.ChatCompletionDelta
---@field content any?
---@field reasoning_content any?
---@field tool_calls openai.ChatToolDelta[]?

---@class openai.ChatCompletionToolCall
---@field id string
---@field type string
---@field ["function"] {name: string, arguments: string}

---@class openai.ChatCompletionMessage
---@field role string
---@field content string?
---@field reasoning_content string?
---@field tool_calls openai.ChatCompletionToolCall[]?
---@field finish_reason string?
---@field usage table?

---@class openai.ChatCompletionsClientOptions
---@field base_url string
---@field api_key string?
---@field timeout number?
---@field request openai.RequestFunc
---@field open_stream openai.OpenStreamFunc?
---@field get_time (fun(): number)?

-- Raw-body transport for OpenAI-compatible Chat Completions endpoints.
-- Returns the full JSON completion or an assembled streamed assistant message;
-- model policy, request allowlists and mandatory usage collection stay outside.
---@class openai.ChatCompletionsClient
---@operator call: openai.ChatCompletionsClient
---@field base_url string
---@field api_key string?
---@field timeout number?
---@field request openai.RequestFunc
---@field open_stream openai.OpenStreamFunc?
---@field active_stream web.HttpStream?
---@field cancel_requested boolean
---@field get_time fun(): number
local Client = class()

Client.max_error_body_size = 64 * 1024
Client.error_label = "OpenAI-compatible"

---@param options openai.ChatCompletionsClientOptions
function Client:new(options)
	assert(type(options.base_url) == "string" and options.base_url ~= "", "base_url is required")
	assert(options.api_key == nil or type(options.api_key) == "string", "api_key must be a string")
	self.base_url = options.base_url:gsub("/$", "")
	self.api_key = options.api_key
	self.timeout = options.timeout
	self.request = assert(options.request, "request is required")
	self.open_stream = options.open_stream
	self.cancel_requested = false
	self.get_time = options.get_time or socket.gettime
end

---@return {[string]: string}
function Client:createHeaders()
	local headers = {
		["Content-Type"] = "application/json",
		Accept = "application/json",
	}
	if self.api_key and self.api_key ~= "" then headers.Authorization = "Bearer " .. self.api_key end
	return headers
end

---@param error_label string
---@param res {status: integer, headers: web.Headers?}
---@param decoded table
---@return openai.ChatCompletionsError
local function providerError(error_label, res, decoded)
	local error_body = type(decoded.error) == "table" and decoded.error or {}
	local message = type(error_body.message) == "string" and error_body.message
		or ("%s provider returned HTTP %d"):format(error_label, res.status)
	local code = type(error_body.code) == "string" and error_body.code or "upstream_error"
	local error_type = type(error_body.type) == "string" and error_body.type or "upstream_error"
	local request_id = res.headers and res.headers:get("x-request-id") or nil
	return {status = res.status, message = message, type = error_type, code = code, request_id = request_id}
end

-- Override only presentation of HTTP failures; SSE errors retain their own
-- provider message and structured metadata.
---@param res {status: integer, headers: web.Headers?}
---@param decoded table
---@return openai.ChatCompletionsError
function Client:httpError(res, decoded)
	return providerError(self.error_label, res, decoded)
end

---@param message any
---@return openai.ChatCompletionMessage?
---@return string?
function Client:validateMessage(message)
	if type(message) ~= "table" or message.role ~= "assistant" then
		return nil, "provider response is missing choices[1].message"
	end
	if message.content ~= nil and message.content ~= json.null and type(message.content) ~= "string" then
		return nil, "assistant message content is not a string"
	end
	if message.content == nil and type(message.tool_calls) ~= "table" then
		return nil, "assistant message has neither text nor tool calls"
	end
	return message
end

--- Sends a non-streaming completion. The body must not set `stream = true`;
--- the client sends `stream = false` explicitly.
---@param body table
---@return table? completion
---@return string? err
---@return openai.ChatCompletionsError? provider_error
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
		return nil, err or (self.error_label .. " request failed")
	end
	local decoded, decode_err = json.decode_safe(res.body)
	if res.status < 200 or res.status >= 300 then
		local provider_error = self:httpError(res, type(decoded) == "table" and decoded or {})
		return nil, provider_error.message, provider_error
	end
	if type(decoded) ~= "table" then
		return nil, "invalid provider JSON: " .. tostring(decode_err)
	end
	local choices = decoded.choices
	local choice = type(choices) == "table" and choices[1] or nil
	local message = type(choice) == "table" and choice.message or nil
	local valid, message_err = self:validateMessage(message)
	if not valid then
		return nil, message_err
	end
	return decoded
end

---@param message openai.ChatCompletionMessage
---@param delta openai.ChatCompletionDelta
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
---@param on_delta (fun(delta: openai.ChatCompletionDelta): boolean?)?
---@return openai.ChatCompletionMessage? message
---@return string? err
---@return openai.ChatCompletionsError? provider_error
function Client:runStream(body, on_delta)
	local deadline = self.timeout and self.get_time() + self.timeout
	local open_stream = assert(self.open_stream, "open_stream is required for streaming")
	self.cancel_requested = false
	local stream, err = open_stream(self.base_url .. "/chat/completions", {
		method = "POST",
		headers = self:createHeaders(),
		timeout = self.timeout,
	})
	if not stream then
		return nil, err or (self.error_label .. " stream failed")
	end
	self.active_stream = stream
	---@return boolean
	local function applyDeadline()
		if not deadline then return true end
		local remaining = deadline - self.get_time()
		if remaining <= 0 then return false end
		stream:setTimeout(remaining)
		return true
	end
	local timeout_error = "upstream request timeout exceeded"
	if not applyDeadline() then
		stream:cancel(timeout_error)
		self.active_stream = nil
		return nil, timeout_error
	end
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
	if not applyDeadline() then
		stream:cancel(timeout_error)
		self.active_stream = nil
		return nil, timeout_error
	end
	headers_ok, err = stream:receiveHeaders()
	if not headers_ok then
		stream:close()
		self.active_stream = nil
		return nil, err
	end
	local res = assert(stream.res)
	if res.status < 200 or res.status >= 300 then
		---@type string[]
		local chunks = {}
		local size = 0
		while applyDeadline() do
			local chunk = stream:receiveAvailableChunk()
			if not chunk then break end
			size = size + #chunk
			if size > self.max_error_body_size then chunks = {} break end
			table.insert(chunks, chunk)
		end
		stream:close()
		self.active_stream = nil
		local decoded = json.decode_safe(table.concat(chunks))
		if type(decoded) == "table" then
			local provider_error = self:httpError(res, decoded)
			return nil, provider_error.message, provider_error
		end
		local provider_error = self:httpError(res, {})
		return nil, provider_error.message, provider_error
	end

	---@type openai.ChatCompletionMessage
	local message = {role = "assistant", content = ""}
	local done = false
	---@type string?
	local parse_err
	---@type openai.ChatCompletionsError?
	local provider_error
	local parser = SseParser(function(data)
		if done or parse_err or self.cancel_requested then return end
		if data == "[DONE]" then
			done = true
			return
		end
		local event, decode_err = json.decode_safe(data)
		---@cast event openai.ChatCompletionResponse?
		if type(event) ~= "table" then
			parse_err = "invalid streaming JSON: " .. tostring(decode_err)
			return
		end
		if type(event.error) == "table" then
			provider_error = providerError(self.error_label, {status = 502, headers = res.headers}, event)
			parse_err = provider_error.message
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
			elseif self.cancel_requested then
				parse_err = "canceled"
			end
		end
	end)

	while not done and not parse_err and not self.cancel_requested do
		if not applyDeadline() then err = timeout_error break end
		local chunk
		chunk, err = stream:receiveAvailableChunk()
		if not chunk then
			break
		end
		parser:feed(chunk)
	end
	if self.cancel_requested and not parse_err then err = "canceled" end
	if not err then parser:finish() end
	if parse_err == "downstream response stream closed" or parse_err == "canceled" or err == "canceled" or err == timeout_error then
		stream:cancel(parse_err or err)
	else
		stream:close()
	end
	self.active_stream = nil
	if parse_err then
		return nil, parse_err, provider_error
	end
	if not done then
		return nil, err or "stream closed before [DONE]"
	end
	if message.finish_reason == nil then
		message.finish_reason = message.tool_calls and "tool_calls" or "stop"
	end
	return self:validateStreamMessage(message)
end

---@param message openai.ChatCompletionMessage
---@return openai.ChatCompletionMessage?
---@return string?
function Client:validateStreamMessage(message)
	if message.content == "" and message.reasoning_content == nil
		and message.tool_calls == nil and message.usage == nil
	then
		return nil, "assistant message has neither text nor tool calls"
	end
	return message
end

---@param body table
---@param on_delta (fun(delta: openai.ChatCompletionDelta): boolean?)?
---@return openai.ChatCompletionMessage?
---@return string?
---@return openai.ChatCompletionsError?
function Client:completeStream(body, on_delta)
	local ok, message, err, provider_error = pcall(self.runStream, self, body, on_delta)
	if ok then return message, err, provider_error end
	local stream = self.active_stream
	self.active_stream = nil
	if stream then pcall(stream.close, stream) end
	return nil, "upstream stream failed"
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
