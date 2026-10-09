local class = require("class")

---@class ai.router.CanonicalUsage
---@field input_tokens integer
---@field output_tokens integer
---@field cached_input_tokens integer included in input_tokens

-- The canonical assistant result every provider returns to the router server.
-- Response id/model wrapping and HTTP chunk shaping stay with the server;
-- providers only translate upstream protocols into this shape.
---@class ai.router.CanonicalMessage
---@field content string
---@field reasoning_content string?
---@field tool_calls table? Chat Completions tool_calls array
---@field finish_reason string?
---@field usage ai.router.CanonicalUsage?

-- Streaming delta shapes relayed to the server:
--   {content = string?}, {reasoning_content = string?}, {tool_calls = table?}
-- mirroring Chat Completions chunk deltas.

-- Shared provider helpers: usage normalization across provider dialects and
-- canonical message assembly.
---@class ai.router.Provider
local Provider = {}

-- Accepts Responses-style usage (`input_tokens`, `output_tokens`,
-- `input_tokens_details.cached_tokens`) and Chat Completions usage
-- (`prompt_tokens`, `completion_tokens`, `prompt_tokens_details.cached_tokens`).
---@param usage {[string]: any}?
---@return ai.router.CanonicalUsage?
function Provider.canonicalUsage(usage)
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
		---@cast details {[string]: any}
		local cached_value = details.cached_tokens
		if type(cached_value) == "number" then cached = cached_value end
	end
	return {
		input_tokens = input,
		output_tokens = output,
		cached_input_tokens = cached,
	}
end

-- Extracts the first choice from a raw provider completion table.
---@param completion {[string]: any}
---@return {[string]: any}? choice
function Provider.completionChoice(completion)
	return completion.choices[1]
end

-- Assembles a canonical message from an upstream assistant message. Extra
-- provider-private fields (for example Responses output items) are dropped.
---@param message {[string]: any}
---@return ai.router.CanonicalMessage
function Provider.canonicalMessage(message)
	---@type ai.router.CanonicalMessage
	local canonical = {
		content = message.content or "",
	}
	if type(message.reasoning_content) == "string" then
		canonical.reasoning_content = message.reasoning_content
	end
	if type(message.tool_calls) == "table" then
		canonical.tool_calls = message.tool_calls
	end
	if type(message.finish_reason) == "string" then
		canonical.finish_reason = message.finish_reason
	end
	canonical.usage = Provider.canonicalUsage(message.usage)
	return canonical
end

return Provider
