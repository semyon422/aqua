local digest = require("digest")
local json = require("web.json")

-- Stateless Responses validation and cache affinity, shared by both HTTP servers.
---@class openai.ResponsesProtocol
local ResponsesProtocol = {}

---@param request {[string]: any}
---@return string? message
---@return string? code
function ResponsesProtocol.validateRequest(request)
	if type(request.input) ~= "string" and not json.isArray(request.input) then
		return "input must be a string or an array", "invalid_input"
	end
	if request.instructions ~= nil and request.instructions ~= json.null and type(request.instructions) ~= "string" then
		return "instructions must be a string", "invalid_instructions"
	end
	if request.stream ~= nil and type(request.stream) ~= "boolean" then
		return "stream must be a boolean", "invalid_stream"
	end
	if request.store ~= nil and request.store ~= json.null and request.store ~= false then
		return "stateful Responses storage is not supported", "unsupported_store"
	end
	if request.background ~= nil and request.background ~= json.null and request.background ~= false then
		return "background Responses are not supported", "unsupported_background"
	end
	if (request.previous_response_id ~= nil and request.previous_response_id ~= json.null)
		or (request.conversation ~= nil and request.conversation ~= json.null) then
		return "server-managed response state is not supported", "unsupported_response_state"
	end
	if request.reasoning ~= nil and request.reasoning ~= json.null then
		if not json.isObject(request.reasoning) then return "reasoning must be an object", "invalid_reasoning" end
		if request.reasoning.effort ~= nil and request.reasoning.effort ~= json.null
			and type(request.reasoning.effort) ~= "string" then
			return "reasoning effort must be a string", "invalid_reasoning"
		end
	end
	if request.text ~= nil and request.text ~= json.null and not json.isObject(request.text) then
		return "text must be an object", "invalid_text"
	end
	if request.include ~= nil and request.include ~= json.null then
		if not json.isArray(request.include) then return "include must be an array", "invalid_include" end
		for _, value in ipairs(request.include) do
			if type(value) ~= "string" then return "include values must be strings", "invalid_include" end
		end
	end
	if request.tools ~= nil and request.tools ~= json.null and not json.isArray(request.tools) then
		return "tools must be an array", "invalid_tools"
	end
	if request.parallel_tool_calls ~= nil and type(request.parallel_tool_calls) ~= "boolean" then
		return "parallel_tool_calls must be a boolean", "invalid_parallel_tool_calls"
	end
	if request.prompt_cache_key ~= nil and (type(request.prompt_cache_key) ~= "string"
		or request.prompt_cache_key == "" or #request.prompt_cache_key > 64) then
		return "prompt_cache_key must contain 1 to 64 bytes", "invalid_prompt_cache_key"
	end
end

local affinity_headers = {"x-session-affinity", "session_id", "x-client-request-id"}

---@param req web.Request
---@return string? session_id
---@return string? error_message
---@return string? source
function ResponsesProtocol.getSessionAffinity(req)
	for _, name in ipairs(affinity_headers) do
		local values = req.headers:getTable(name)
		if #values > 1 then return nil, "multiple " .. name .. " headers are not allowed" end
		local value = values[1]
		if value then
			if #value < 1 or #value > 128 or not value:match("^[%w._:%-]+$") then
				return nil, name .. " must contain 1 to 128 letters, digits, or ._:-"
			end
			return value, nil, name
		end
	end
end

---@param key string?
---@return string?
function ResponsesProtocol.cacheSessionId(key)
	if key then return digest.hash("sha256", key, true) end
end

return ResponsesProtocol
