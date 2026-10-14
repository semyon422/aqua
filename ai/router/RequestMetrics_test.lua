local RequestMetrics = require("ai.router.RequestMetrics")

local test = {}

---@param t testing.T
function test.output_timing_is_optional_and_first_output_is_stable(t)
	local now = 100
	local metrics = RequestMetrics(function() return now end)
	t:eq(metrics:ttftMs(), nil)
	t:eq(metrics:generationMs(), nil)
	now = 102
	metrics:markOutput()
	now = 104
	metrics:markOutput()
	now = 106
	metrics:finishGeneration()
	t:eq(metrics:ttftMs(), 2000)
	t:eq(metrics:generationMs(), 4000)
	local empty = RequestMetrics(function() return now end)
	empty:finishGeneration()
	t:eq(empty:ttftMs(), nil)
	t:eq(empty:generationMs(), nil)
end

---@param t testing.T
function test.only_output_events_start_ttft(t)
	for _, delta in ipairs({{}, {role = "assistant"}, {content = ""}, {content = false}, {tool_calls = {}},
		{tool_calls = {{index = 0, id = "call_1", type = "function"}}}}) do
		t:eq(RequestMetrics.chatOutput(delta), false)
	end
	for _, delta in ipairs({{content = "hi"}, {reasoning_content = "thinking"},
		{tool_calls = {{index = 0, ["function"] = {arguments = "{}"}}}}}) do
		t:eq(RequestMetrics.chatOutput(delta), true)
	end
	for _, name in ipairs({"response.created", "response.in_progress", "response.completed", "response.output_item.added"}) do
		t:eq(RequestMetrics.responseOutput({type = name, delta = "not-output"}), false)
	end
	for _, name in ipairs({"response.output_text.delta", "response.function_call_arguments.delta",
		"response.reasoning_summary_text.delta", "response.reasoning_text.delta", "response.refusal.delta"}) do
		t:eq(RequestMetrics.responseOutput({type = name, delta = ""}), false)
		t:eq(RequestMetrics.responseOutput({type = name, delta = "hi"}), true)
	end
end

---@param t testing.T
function test.error_codes_are_closed_and_disconnect_takes_precedence(t)
	---@type {status: integer, code: string?, expected: ai.router.RequestErrorCode}[]
	local cases = {
		{status = 429, expected = "rate_limit"},
		{status = 429, code = "concurrency_limit_exceeded", expected = "concurrency_limit"},
		{status = 400, code = "unsupported_protocol", expected = "unsupported_protocol"},
		{status = 404, code = "model_not_found", expected = "model_not_found"},
		{status = 401, expected = "auth"}, {status = 403, expected = "auth"},
		{status = 504, expected = "timeout"}, {status = 408, expected = "timeout"},
		{status = 400, code = "PRIVATE-PAYLOAD", expected = "invalid_request"},
		{status = 503, expected = "upstream_unavailable"},
		{status = 502, code = "PRIVATE-PAYLOAD", expected = "upstream_error"},
	}
	for _, case in ipairs(cases) do
		local metrics = RequestMetrics(function() return 100 end)
		metrics:setError(case.status, case.code)
		t:eq(metrics:outcomeCode(case.status), case.expected)
		t:eq(metrics:outcomeCode(499), "client_disconnected")
		t:eq(metrics:outcomeCode(200), nil)
	end
	local metrics = RequestMetrics(function() return 100 end)
	t:eq(metrics:outcomeCode(500), "internal_error")
	metrics:providerError("upstream request timeout exceeded PRIVATE", nil)
	t:eq(metrics:outcomeCode(502), "timeout")
	metrics:providerError("OpenAI subscription request deadline exceeded", nil)
	t:eq(metrics:outcomeCode(502), "timeout")
	metrics = RequestMetrics(function() return 100 end)
	metrics:providerError(nil, {code = "rate_limit_exceeded"})
	t:eq(metrics:outcomeCode(502), "rate_limit")
	metrics = RequestMetrics(function() return 100 end)
	metrics:providerError(nil, {code = "token_expired"})
	t:eq(metrics:outcomeCode(502), "auth")
end

return test
