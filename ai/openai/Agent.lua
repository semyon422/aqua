local class = require("class")
local json = require("web.json")

---@class aqua.openai.Message
---@field role "developer"|"system"|"user"|"assistant"|"tool"
---@field content string|table[]?
---@field finish_reason "stop"|"length"|"tool_calls"|"content_filter"?
---@field tool_calls aqua.openai.ToolCall[]?
---@field tool_call_id string?
---@field response_items table[]? Provider-owned Responses API items retained across tool rounds.
---@field reasoning_content string? Provider-generated reasoning summary exposed by compatible chat clients.
---@field usage aqua.openai.TokenUsage?

---@class aqua.openai.InputTokenDetails
---@field cached_tokens integer?
---@field audio_tokens integer?

---@class aqua.openai.OutputTokenDetails
---@field reasoning_tokens integer?
---@field audio_tokens integer?
---@field accepted_prediction_tokens integer?
---@field rejected_prediction_tokens integer?

---@class aqua.openai.TokenUsage
---@field input_tokens integer
---@field output_tokens integer
---@field total_tokens integer
---@field input_tokens_details aqua.openai.InputTokenDetails?
---@field output_tokens_details aqua.openai.OutputTokenDetails?

---@class aqua.openai.ToolCallFunction
---@field name string
---@field arguments string

---@class aqua.openai.ToolCall
---@field id string
---@field type "function"
---@field ["function"] aqua.openai.ToolCallFunction

---@class aqua.openai.ToolSchema
---@field type "function"
---@field ["function"] table

---@class aqua.openai.Tool
---@field name string
---@field schema aqua.openai.ToolSchema
---@field execute fun(self: aqua.openai.Tool, args: {[string]: any}): string, boolean?

---@class aqua.openai.AgentOptions
---@field max_tool_rounds integer?
---@field on_tool_result fun(tool_call: aqua.openai.ToolCall, content: string)?
---@field on_tool_failure fun(name: string?, arguments: any, err: string)?
---@field on_text_delta fun(content: string)?
---@field streaming boolean?

---@class aqua.openai.Agent
---@operator call: aqua.openai.Agent
---@field client aqua.openai.Client|aqua.openai.SubscriptionClient
---@field tools {[string]: aqua.openai.Tool}
---@field tool_schemas aqua.openai.ToolSchema[]
---@field max_tool_rounds integer
---@field on_tool_result fun(tool_call: aqua.openai.ToolCall, content: string)?
---@field on_tool_failure fun(name: string?, arguments: any, err: string)?
---@field on_text_delta fun(content: string)?
---@field streaming boolean
local Agent = class()

---@param client aqua.openai.Client|aqua.openai.SubscriptionClient
---@param tools aqua.openai.Tool[]
---@param options aqua.openai.AgentOptions?
function Agent:new(client, tools, options)
	options = options or {}
	self.client = client
	self.tools = {}
	self.tool_schemas = {}
	self.max_tool_rounds = options.max_tool_rounds or 8
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

---@param client aqua.openai.Client|aqua.openai.SubscriptionClient
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
function Agent:toolError(name, arguments, err)
	self:reportToolFailure(name, arguments, err)
	return encodeError(err)
end

---@param tool_call aqua.openai.ToolCall
---@return string
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
	return content
end

---@param messages aqua.openai.Message[]
---@param on_text_delta fun(content: string)?
---@return aqua.openai.Message?
---@return string?
function Agent:run(messages, on_text_delta)
	for _ = 1, self.max_tool_rounds + 1 do
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
			local content = self:executeTool(tool_call)
			table.insert(messages, {
				role = "tool",
				tool_call_id = tool_call.id,
				content = content,
			})
			if self.on_tool_result then
				self.on_tool_result(tool_call, content)
			end
		end
	end
end

---@return boolean
function Agent:cancel()
	return self.client:cancel()
end

return Agent
