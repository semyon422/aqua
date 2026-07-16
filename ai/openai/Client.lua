local class = require("class")
local json = require("web.json")
local SseParser = require("ai.openai.SseParser")

---@alias aqua.openai.RequestFunc fun(url: string, body: table|string?, options: web.HttpRequestOptions?): {status: integer, headers: web.Headers?, body: string}?, string?
---@alias aqua.openai.OpenStreamFunc fun(url: string, options: web.HttpStreamOptions?): web.HttpStream?, string?

---@class aqua.openai.ClientOptions
---@field base_url string
---@field api_key string?
---@field model string
---@field max_tokens integer?
---@field timeout number?
---@field request aqua.openai.RequestFunc
---@field open_stream aqua.openai.OpenStreamFunc?

---@class aqua.openai.Client
---@operator call: aqua.openai.Client
---@field base_url string
---@field api_key string?
---@field model string
---@field max_tokens integer?
---@field timeout number?
---@field request aqua.openai.RequestFunc
---@field open_stream aqua.openai.OpenStreamFunc?
---@field active_stream web.HttpStream?
---@field cancel_requested boolean
local Client = class()

---@param options aqua.openai.ClientOptions
function Client:new(options)
	assert(options.base_url ~= "", "base_url is required")
	assert(options.model ~= "", "model is required")
	self.base_url = options.base_url:gsub("/$", "")
	self.api_key = options.api_key
	self.model = options.model
	self.max_tokens = options.max_tokens
	self.timeout = options.timeout
	self.request = assert(options.request, "request is required")
	self.open_stream = options.open_stream
	self.cancel_requested = false
end

---@param messages aqua.openai.Message[]
---@param tools aqua.openai.ToolSchema[]?
---@param stream boolean
---@return table
function Client:createBody(messages, tools, stream)
	local body = {
		model = self.model,
		messages = messages,
		stream = stream,
	}
	if tools and #tools > 0 then
		body.tools = tools
		body.tool_choice = "auto"
		body.parallel_tool_calls = false
	end
	if self.max_tokens then
		body.max_tokens = self.max_tokens
	end
	return body
end

---@return {[string]: string}
function Client:createHeaders()
	local headers = {
		["Content-Type"] = "application/json",
	}
	if self.api_key and self.api_key ~= "" then
		headers.Authorization = "Bearer " .. self.api_key
	end
	return headers
end

---@param message any
---@return aqua.openai.Message?
---@return string?
function Client:validateMessage(message)
	if type(message) ~= "table" or message.role ~= "assistant" then
		return nil, "provider response is missing choices[1].message"
	end
	if type(message.content) ~= "string" and type(message.tool_calls) ~= "table" then
		return nil, "assistant message has neither text nor tool calls"
	end
	return message
end

---@param messages aqua.openai.Message[]
---@param tools aqua.openai.ToolSchema[]?
---@return aqua.openai.Message?
---@return string?
function Client:complete(messages, tools)
	local res, err = self.request(self.base_url .. "/chat/completions", json.encode(self:createBody(messages, tools, false)), {
		method = "POST",
		headers = self:createHeaders(),
		timeout = self.timeout,
	})
	if not res then
		return nil, err or "OpenAI-compatible request failed"
	end

	local decoded, decode_err = json.decode_safe(res.body)
	if not decoded then
		return nil, "invalid provider JSON: " .. tostring(decode_err)
	end
	if type(decoded) ~= "table" then
		return nil, "invalid provider response"
	end

	if res.status < 200 or res.status >= 300 then
		local provider_error = decoded.error
		if type(provider_error) == "table" and type(provider_error.message) == "string" then
			return nil, ("provider returned HTTP %d: %s"):format(res.status, provider_error.message)
		end
		return nil, ("provider returned HTTP %d"):format(res.status)
	end

	local choices = decoded.choices
	local choice = type(choices) == "table" and choices[1] or nil
	local message = type(choice) == "table" and choice.message or nil
	return self:validateMessage(message)
end

---@param message aqua.openai.Message
---@param delta table
---@param on_text_delta fun(content: string)?
function Client:applyDelta(message, delta, on_text_delta)
	if type(delta.content) == "string" and delta.content ~= "" then
		message.content = (message.content or "") .. delta.content
		if on_text_delta then
			on_text_delta(delta.content)
		end
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

---@param messages aqua.openai.Message[]
---@param tools aqua.openai.ToolSchema[]?
---@param on_text_delta fun(content: string)?
---@return aqua.openai.Message?
---@return string?
function Client:completeStream(messages, tools, on_text_delta)
	local open_stream = assert(self.open_stream, "open_stream is required for streaming")
	self.cancel_requested = false
	local stream, err = open_stream(self.base_url .. "/chat/completions", {
		method = "POST",
		headers = self:createHeaders(),
		timeout = self.timeout,
	})
	if not stream then
		return nil, err or "OpenAI-compatible stream failed"
	end
	self.active_stream = stream
	if self.cancel_requested then
		stream:cancel("canceled")
		self.active_stream = nil
		return nil, "canceled"
	end

	local body = json.encode(self:createBody(messages, tools, true))
	local sent
	sent, err = stream:sendBody(body)
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
		return nil, ("provider returned HTTP %d: %s"):format(res.status, error_body or "")
	end

	---@type aqua.openai.Message
	local message = {role = "assistant", content = ""}
	local done = false
	local parse_err
	local parser = SseParser(function(data)
		if data == "[DONE]" then
			done = true
			return
		end
		local event, decode_err = json.decode_safe(data)
		if not event then
			parse_err = "invalid streaming JSON: " .. tostring(decode_err)
			return
		end
		if type(event.error) == "table" then
			parse_err = tostring(event.error.message or "provider streaming error")
			return
		end
		local choice = type(event.choices) == "table" and event.choices[1] or nil
		if type(choice) == "table" and type(choice.delta) == "table" then
			self:applyDelta(message, choice.delta, on_text_delta)
		end
	end)

	while not done and not parse_err do
		local chunk
		chunk, err = stream:receiveChunk()
		if not chunk then
			break
		end
		parser:feed(chunk)
	end
	parser:finish()
	stream:close()
	self.active_stream = nil
	if parse_err then
		return nil, parse_err
	end
	if not done then
		return nil, err or "stream closed before [DONE]"
	end
	return self:validateMessage(message)
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
