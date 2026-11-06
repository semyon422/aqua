local json = require("web.json")

-- Pure Chat Completions shapes and accounting normalization, shared by HTTP
-- relays and adapters. No routing, HTTP writes, clocks or collection policy.
local Protocol = {}

---@class openai.CanonicalUsage
---@field input_tokens integer
---@field output_tokens integer
---@field cached_input_tokens integer included in input_tokens

---@class openai.CanonicalMessage
---@field content string
---@field reasoning any? Provider extension, retained under its original name.
---@field reasoning_content any? Provider extension, retained under its original name.
---@field refusal any?
---@field tool_calls table?
---@field finish_reason string?
---@field usage openai.CanonicalUsage?
---@field wire_usage table? Reported Chat Completions counters/details, separate from accounting.

-- Accepts both native Responses and Chat Completions usage for accounting.
-- This never rewrites native Responses objects or events on the wire.
---@param usage table?
---@return openai.CanonicalUsage?
function Protocol.canonicalUsage(usage)
	if type(usage) ~= "table" then return nil end
	local input = usage.input_tokens
	local output = usage.output_tokens
	local cached = 0
	if type(input) ~= "number" then
		input = usage.prompt_tokens
		output = usage.completion_tokens
	end
	if type(input) ~= "number" or type(output) ~= "number" then return nil end
	local details = usage.input_tokens_details
	if type(details) ~= "table" then details = usage.prompt_tokens_details end
	if type(details) == "table" then
		local cached_value = details.cached_tokens
		if type(cached_value) == "number" then cached = cached_value end
	end
	return {input_tokens = input, output_tokens = output, cached_input_tokens = cached}
end

-- Keep supported assistant output fields without leaking provider metadata.
---@param message table
---@param reported_usage table? Completion-level usage takes precedence over legacy message-level usage.
---@return openai.CanonicalMessage
function Protocol.canonicalMessage(message, reported_usage)
	---@type openai.CanonicalMessage
	local canonical = {content = message.content or ""}
	for _, key in ipairs({"reasoning", "reasoning_content", "refusal"}) do
		if message[key] ~= nil then canonical[key] = message[key] end
	end
	if type(message.tool_calls) == "table" then canonical.tool_calls = message.tool_calls end
	if type(message.finish_reason) == "string" then canonical.finish_reason = message.finish_reason end
	local raw_usage = type(reported_usage) == "table" and reported_usage ~= json.null
		and not json.isArray(reported_usage) and reported_usage or message.usage
	canonical.usage = Protocol.canonicalUsage(raw_usage)
	canonical.wire_usage = Protocol.completionUsage(canonical.usage, raw_usage)
	return canonical
end

-- Preserve the known Chat Completions wire fields independently of normalized
-- accounting. Detail objects (including zero, null and provider-specific nested
-- entries) are not flattened or guessed. Unknown top-level metadata is not exposed.
---@param usage openai.CanonicalUsage?
---@param reported_usage table?
---@return table?
function Protocol.completionUsage(usage, reported_usage)
	local native = type(reported_usage) == "table" and type(reported_usage.input_tokens) == "number"
		and type(reported_usage.output_tokens) == "number" and reported_usage.prompt_tokens == nil
		and reported_usage.completion_tokens == nil
	if type(reported_usage) == "table" and reported_usage ~= json.null and not json.isArray(reported_usage) and not native then
		local reported = json.object()
		for _, key in ipairs({"prompt_tokens", "completion_tokens", "total_tokens",
			"prompt_tokens_details", "completion_tokens_details"}) do
			if reported_usage[key] ~= nil then reported[key] = reported_usage[key] end
		end
		if next(reported) then return reported end
	end
	if not usage then return nil end
	local result = {prompt_tokens = usage.input_tokens, completion_tokens = usage.output_tokens,
		total_tokens = usage.input_tokens + usage.output_tokens}
	if usage.cached_input_tokens > 0 then
		result.prompt_tokens_details = {cached_tokens = usage.cached_input_tokens}
	end
	return result
end

-- Provider-specific validation/allowlisting of terminal reasons belongs to the
-- adapter. Preserve explicit reasons; infer only when the provider omits one.
---@param message openai.CanonicalMessage
---@return string
function Protocol.finishReason(message)
	if message.finish_reason then return message.finish_reason end
	if message.tool_calls and message.tool_calls[1] then return "tool_calls" end
	return "stop"
end

---@param completion_id string
---@param created integer
---@param model string
---@param message openai.CanonicalMessage
---@return table
function Protocol.completion(completion_id, created, model, message)
	local wire_message = {role = "assistant", content = message.content}
	for _, key in ipairs({"reasoning", "reasoning_content", "refusal", "tool_calls"}) do
		if message[key] ~= nil then wire_message[key] = message[key] end
	end
	return {id = completion_id, object = "chat.completion", created = created, model = model,
		choices = {{index = 0, message = wire_message, finish_reason = Protocol.finishReason(message)}},
		usage = message.wire_usage or Protocol.completionUsage(message.usage)}
end

---@param completion_id string
---@param created integer
---@param model string
---@param delta table
---@param finish_reason string?
---@param include_usage boolean?
---@return table
function Protocol.chunk(completion_id, created, model, delta, finish_reason, include_usage)
	return {id = completion_id, object = "chat.completion.chunk", created = created, model = model,
		choices = {{index = 0, delta = delta, finish_reason = finish_reason}},
		usage = include_usage and json.null or nil}
end

-- Usage is already in the Chat Completions wire format. Retain extended fields
-- supplied by the caller (e.g. reasoning-token details in a provider relay).
---@param completion_id string
---@param created integer
---@param model string
---@param usage table
---@return table
function Protocol.usageChunk(completion_id, created, model, usage)
	return {id = completion_id, object = "chat.completion.chunk", created = created, model = model,
		choices = json.array({}), usage = usage}
end

---@param delta table
---@return boolean
function Protocol.hasOutput(delta)
	for _, key in ipairs({"content", "reasoning_content", "reasoning", "refusal"}) do
		local value = delta[key]
		if type(value) == "string" and value ~= "" then return true end
	end
	if type(delta.tool_calls) == "table" then
		for _, call in ipairs(delta.tool_calls) do
			if type(call) == "table" and type(call["function"]) == "table" then
				local f = call["function"]
				if type(f.name) == "string" and f.name ~= ""
					or type(f.arguments) == "string" and f.arguments ~= "" then return true end
			end
		end
	end
	local f = delta.function_call
	if type(f) == "table" and (type(f.name) == "string" and f.name ~= ""
		or type(f.arguments) == "string" and f.arguments ~= "") then return true end
	local audio = delta.audio
	if type(audio) == "table" and type(audio.data) == "string" and audio.data ~= "" then return true end
	return false
end

return Protocol
