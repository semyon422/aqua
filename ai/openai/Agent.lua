local class = require("class")
local json = require("web.json")

---@class openai.Message
---@field role "developer"|"system"|"user"|"assistant"|"tool"
---@field content string|table[]?
---@field finish_reason "stop"|"length"|"tool_calls"|"content_filter"?
---@field tool_calls openai.ToolCall[]?
---@field tool_call_id string?
---@field response_items table[]? Provider-owned Responses API items retained across tool rounds.
---@field reasoning_content string? Provider-generated reasoning summary exposed by compatible chat clients.
---@field usage openai.TokenUsage?

---@class openai.InputTokenDetails
---@field cached_tokens integer?
---@field audio_tokens integer?

---@class openai.OutputTokenDetails
---@field reasoning_tokens integer?
---@field audio_tokens integer?
---@field accepted_prediction_tokens integer?
---@field rejected_prediction_tokens integer?

---@class openai.TokenUsage
---@field input_tokens integer
---@field output_tokens integer
---@field total_tokens integer
---@field input_tokens_details openai.InputTokenDetails?
---@field output_tokens_details openai.OutputTokenDetails?

---@class openai.ToolCallFunction
---@field name string
---@field arguments string

---@class openai.ToolCall
---@field id string
---@field type "function"
---@field ["function"] openai.ToolCallFunction

---@class openai.FunctionSchema
---@field name string
---@field description string?
---@field parameters table
---@field strict boolean?

---@class openai.ToolSchema
---@field type "function"
---@field ["function"] openai.FunctionSchema

---@class openai.Tool
---@field name string
---@field schema openai.ToolSchema
---@field execute fun(self: openai.Tool, args: {[string]: any}): string, boolean?

---@class openai.AgentOptions
---@field max_tool_rounds integer?
---@field on_tool_call fun(tool_call: openai.ToolCall)?
---@field on_tool_result fun(tool_call: openai.ToolCall, content: string, is_error: boolean)?
---@field on_tool_failure fun(name: string?, arguments: any, err: string)?
---@field on_text_delta fun(content: string)?
---@field streaming boolean?

---@class openai.Agent
---@operator call: openai.Agent
---@field client openai.Client|openai.SubscriptionClient
---@field tools {[string]: openai.Tool}
---@field tool_schemas openai.ToolSchema[]
---@field max_tool_rounds integer
---@field on_tool_call fun(tool_call: openai.ToolCall)?
---@field on_tool_result fun(tool_call: openai.ToolCall, content: string, is_error: boolean)?
---@field on_tool_failure fun(name: string?, arguments: any, err: string)?
---@field on_text_delta fun(content: string)?
---@field streaming boolean
local Agent = class()

---@param client openai.Client|openai.SubscriptionClient
---@param tools openai.Tool[]
---@param options openai.AgentOptions?
function Agent:new(client, tools, options)
	options = options or {}
	self.client = client
	self.tools = {}
	self.tool_schemas = {}
	self.max_tool_rounds = options.max_tool_rounds or 8
	self.on_tool_call = options.on_tool_call
	self.on_tool_result = options.on_tool_result
	self.on_tool_failure = options.on_tool_failure
	self.on_text_delta = options.on_text_delta
	self.streaming = options.streaming == true
	for _, tool in ipairs(tools) do
		assert(not self.tools[tool.name], "duplicate tool: " .. tool.name)
		self.tools[tool.name] = tool
		table.insert(self.tool_schemas, tool.schema)
	end
end

---@param client openai.Client|openai.SubscriptionClient
function Agent:setClient(client)
	self.client = client
end

---@param message string
---@return string
local function encodeError(message)
	return json.encode({ok = false, error = message})
end

---@param name string?
---@param arguments any
---@param err string
function Agent:reportToolFailure(name, arguments, err)
	local callback = self.on_tool_failure
	if callback then
		pcall(callback, name, arguments, err)
	end
end

---@param name string?
---@param arguments any
---@param err string
---@return string
---@return true
function Agent:toolError(name, arguments, err)
	self:reportToolFailure(name, arguments, err)
	return encodeError(err), true
end

---@param tool_call openai.ToolCall
---@return string
---@return boolean is_error
function Agent:executeTool(tool_call)
	local call_function = tool_call["function"]
	if type(tool_call.id) ~= "string" or type(call_function) ~= "table" then
		return self:toolError(nil, tool_call, "invalid tool call")
	end

	local name = call_function.name
	local tool = type(name) == "string" and self.tools[name] or nil
	if not tool then
		return self:toolError(type(name) == "string" and name or nil, call_function.arguments, "unknown tool: " .. tostring(name))
	end

	local args, err = json.decode_safe(call_function.arguments or "")
	if type(args) ~= "table" then
		return self:toolError(name, call_function.arguments, "invalid tool arguments: " .. tostring(err or "expected a JSON object"))
	end

	local ok, content, is_error = xpcall(tool.execute, debug.traceback, tool, args)
	if not ok then
		return self:toolError(name, args, tostring(content))
	end
	if type(content) ~= "string" then
		return self:toolError(name, args, "tool returned a non-string result")
	end
	if is_error == true then
		self:reportToolFailure(name, args, content)
	end
	return content, is_error == true
end

---@param messages openai.Message[]
---@param on_text_delta fun(content: string)?
---@return openai.Message?
---@return string?
function Agent:run(messages, on_text_delta)
	for _ = 1, self.max_tool_rounds + 1 do
		---@type openai.Message?, string?
		local message, err
		if self.streaming then
			message, err = self.client:completeStream(messages, self.tool_schemas, on_text_delta or self.on_text_delta)
		else
			message, err = self.client:complete(messages, self.tool_schemas)
		end
		if not message then
			return nil, err
		end
		table.insert(messages, message)

		local tool_calls = message.tool_calls
		if type(tool_calls) ~= "table" or #tool_calls == 0 then
			return message
		end

		if _ > self.max_tool_rounds then
			return nil, "tool round limit exceeded"
		end

		for _, tool_call in ipairs(tool_calls) do
			if type(tool_call.id) ~= "string" then
				return nil, "provider returned a tool call without an id"
			end
			if self.on_tool_call then
				self.on_tool_call(tool_call)
			end
			local content, is_error = self:executeTool(tool_call)
			table.insert(messages, {
				role = "tool",
				tool_call_id = tool_call.id,
				content = content,
			})
			if self.on_tool_result then
				self.on_tool_result(tool_call, content, is_error)
			end
		end
	end
end

---@return boolean
function Agent:cancel()
	return self.client:cancel()
end

return Agent
