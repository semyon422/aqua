local ChatCompletionsClient = require("ai.openai.ChatCompletionsClient")

---@class openai.ChatBody
---@field model string
---@field messages openai.Message[]
---@field stream boolean
---@field tools openai.ToolSchema[]?
---@field tool_choice "auto"?
---@field parallel_tool_calls boolean?
---@field max_tokens integer?

---@alias openai.ChatProviderError openai.ChatErrorBody
---@alias openai.ChatProviderChoice openai.ChatCompletionChoice
---@alias openai.ProviderResponse openai.ChatCompletionResponse
---@alias openai.ChatToolCallDeltaFunction openai.ChatFunctionDelta
---@alias openai.ChatToolCallDelta openai.ChatToolDelta
---@alias openai.MessageDelta openai.ChatCompletionDelta

---@class openai.ClientOptions : openai.ChatCompletionsClientOptions
---@field model string
---@field max_tokens integer?

-- Agent-facing facade: accepts message/tool arrays and returns one assistant
-- message, while the shared transport owns HTTP, SSE and stream cleanup.
---@class openai.Client : openai.ChatCompletionsClient
---@operator call: openai.Client
---@field model string
---@field max_tokens integer?
local Client = ChatCompletionsClient + {}

---@param options openai.ClientOptions
function Client:new(options)
	assert(type(options.model) == "string" and options.model ~= "", "model is required")
	ChatCompletionsClient.new(self, options)
	self.model = options.model
	self.max_tokens = options.max_tokens
end

---@param messages openai.Message[]
---@param tools openai.ToolSchema[]?
---@param stream boolean
---@return openai.ChatBody
function Client:createBody(messages, tools, stream)
	---@type openai.ChatBody
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
	local headers = ChatCompletionsClient.createHeaders(self)
	headers.Accept = nil
	return headers
end

---@param res {status: integer, headers: web.Headers?}
---@param decoded table
---@return openai.ChatCompletionsError
function Client:httpError(res, decoded)
	local provider_error = ChatCompletionsClient.httpError(self, res, decoded)
	provider_error.message = ("provider returned HTTP %d"):format(res.status)
	if type(decoded.error) == "table" and type(decoded.error.message) == "string" then
		provider_error.message = provider_error.message .. ": " .. decoded.error.message
	end
	return provider_error
end

---@param message any
---@return openai.Message?
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

-- The agent facade has always accepted an empty assistant text message.
---@param message openai.ChatCompletionMessage
---@return openai.Message?
---@return string?
function Client:validateStreamMessage(message)
	return self:validateMessage(message)
end

---@param messages openai.Message[]
---@param tools openai.ToolSchema[]?
---@return openai.Message?
---@return string?
function Client:complete(messages, tools)
	local completion, err = ChatCompletionsClient.complete(self, self:createBody(messages, tools, false))
	if not completion then return nil, err end
	return completion.choices[1].message
end

---@param message openai.Message
---@param delta openai.MessageDelta
---@param on_text_delta fun(content: string)?
function Client:applyDelta(message, delta, on_text_delta)
	ChatCompletionsClient.applyDelta(self, message, delta)
	if on_text_delta and type(delta.content) == "string" and delta.content ~= "" then
		on_text_delta(delta.content)
	end
end

---@param messages openai.Message[]
---@param tools openai.ToolSchema[]?
---@param on_text_delta (fun(content: string): boolean?)?
---@return openai.Message?
---@return string?
function Client:completeStream(messages, tools, on_text_delta)
	local on_delta
	if on_text_delta then
		on_delta = function(delta)
			if type(delta.content) == "string" and delta.content ~= "" then
				return on_text_delta(delta.content)
			end
		end
	end
	local message, err = ChatCompletionsClient.completeStream(self, self:createBody(messages, tools, true), on_delta)
	if not message then return nil, err end
	return message
end

return Client
