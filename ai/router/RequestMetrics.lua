local class = require("class")

---@alias ai.router.RequestErrorCode "rate_limit"|"concurrency_limit"|"timeout"|"auth"|"client_disconnected"|"model_not_found"|"unsupported_protocol"|"invalid_request"|"upstream_unavailable"|"upstream_error"|"internal_error"

---@class ai.router.RequestMetrics
---@operator call: ai.router.RequestMetrics
---@field get_time fun(): number
---@field started_at number
---@field first_output_at number?
---@field finished_at number?
---@field error_code ai.router.RequestErrorCode?
local RequestMetrics = class()

---@param get_time fun(): number
function RequestMetrics:new(get_time)
	self.get_time = get_time
	self.started_at = get_time()
end

function RequestMetrics:markOutput()
	if not self.first_output_at then self.first_output_at = self.get_time() end
end

function RequestMetrics:finishGeneration()
	self.finished_at = self.get_time()
end

---@return integer? ttft_ms
function RequestMetrics:ttftMs()
	if self.first_output_at then
		return math.max(0, math.floor((self.first_output_at - self.started_at) * 1000 + 0.5))
	end
end

---@return integer? generation_ms
function RequestMetrics:generationMs()
	if self.first_output_at and self.finished_at then
		return math.max(0, math.floor((self.finished_at - self.first_output_at) * 1000 + 0.5))
	end
end

---@param status integer
---@param code string?
function RequestMetrics:setError(status, code)
	if self.error_code then return end
	if code == "concurrency_limit_exceeded" then self.error_code = "concurrency_limit"
	elseif code == "unsupported_protocol" then self.error_code = "unsupported_protocol"
	elseif code == "model_not_found" then self.error_code = "model_not_found"
	elseif status == 429 or code == "rate_limit_exceeded" then self.error_code = "rate_limit"
	elseif status == 401 or status == 403 then self.error_code = "auth"
	elseif status == 408 or status == 504 then self.error_code = "timeout"
	elseif status == 503 then self.error_code = "upstream_unavailable"
	elseif status >= 400 and status < 500 then self.error_code = "invalid_request"
	elseif status >= 500 then self.error_code = "upstream_error" end
end

---@param err string?
---@param provider_error {[string]: any}?
function RequestMetrics:providerError(err, provider_error)
	if provider_error then
		local status = type(provider_error.status) == "number" and provider_error.status or 502
		if provider_error.type == "rate_limit_error" then status = 429 end
		if provider_error.type == "authentication_error" or provider_error.code == "invalid_api_key"
			or provider_error.code == "token_expired" then status = 401 end
		self:setError(status, provider_error.code)
	elseif type(err) == "string" and (err:lower():find("timeout", 1, true)
		or err:lower():find("timed out", 1, true) or err:lower():find("deadline exceeded", 1, true)) then
		self.error_code = "timeout"
	else
		self.error_code = "upstream_error"
	end
end

---@param status integer
---@return ai.router.RequestErrorCode?
function RequestMetrics:outcomeCode(status)
	if status < 400 then return end
	if status == 499 then return "client_disconnected" end
	return self.error_code or (status == 500 and "internal_error" or status == 429 and "rate_limit" or "upstream_error")
end

---@param delta {[string]: any}
---@return boolean
function RequestMetrics.chatOutput(delta)
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

---@param event {[string]: any}
---@return boolean
function RequestMetrics.responseOutput(event)
	local event_type = event.type
	return (event_type == "response.output_text.delta" or event_type == "response.refusal.delta"
		or event_type == "response.reasoning_text.delta" or event_type == "response.reasoning_summary_text.delta"
		or event_type == "response.function_call_arguments.delta" or event_type == "response.audio.delta")
		and type(event.delta) == "string" and event.delta ~= ""
end

return RequestMetrics
