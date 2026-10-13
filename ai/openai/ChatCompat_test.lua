local ChatCompat = require("ai.openai.ChatCompat")
local json = require("web.json")

local test = {}

---@param body {[string]: any}
---@return openai.ChatCompatRequest?
---@return string?
---@return string?
local function normalize(body)
	return ChatCompat.normalizeRequest(json.decode(json.encode(body)))
end

---@param t testing.T
function test.normalizes_completion_controls_and_shapes_result(t)
	local compat = assert(normalize({
		messages = {{role = "user", content = "hi"}}, reasoning_effort = "high",
		max_completion_tokens = 2048, parallel_tool_calls = false, verbosity = "high",
		temperature = 1, top_p = 1, n = 1, stop = {}, logprobs = false,
		frequency_penalty = 0, presence_penalty = 0, logit_bias = json.object(),
		prompt_cache_key = "thread", prompt_cache_options = {mode = "explicit", ttl = "30m"},
		tools = {{type = "function", ["function"] = {name = "inspect", parameters = {type = "object"}}}},
		tool_choice = {type = "function", ["function"] = {name = "inspect"}},
		response_format = {type = "json_schema", json_schema = {
			name = "answer", schema = {type = "object"}, strict = true,
		}},
	}))
	t:eq(compat.reasoning_effort, "high")
	t:eq(compat.client_options.parallel_tool_calls, false)
	t:eq(compat.client_options.prompt_cache_key, "thread")
	t:eq(compat.client_options.prompt_cache_options.ttl, "30m")
	t:eq(compat.client_options.tool_choice.name, "inspect")
	t:eq(compat.client_options.text_format.name, "answer")
	local completion = ChatCompat.createCompletion("model", {
		role = "assistant", content = "hello", finish_reason = "length",
		reasoning_content = "brief thought",
		response_items = {{type = "reasoning", encrypted_content = "private"}},
		usage = {input_tokens = 12, output_tokens = 5, total_tokens = 17,
			input_tokens_details = {cached_tokens = 8}},
	}, "chatcmpl-test", 1000, false)
	t:eq(completion.choices[1].finish_reason, "length")
	t:eq(completion.choices[1].message.reasoning_content, "brief thought")
	t:eq(completion.choices[1].message.response_items, nil)
	t:eq(completion.usage.prompt_tokens, 12)
	t:eq(completion.usage.prompt_tokens_details.cached_tokens, 8)
end

---@param t testing.T
function test.normalizes_legacy_function_history_and_deltas(t)
	local compat = assert(normalize({
		messages = {
			{role = "user", content = "inspect"},
			{role = "assistant", content = json.null,
				function_call = {name = "inspect", arguments = [[{"path":"old"}]]}},
			{role = "function", name = "inspect", content = "old result"},
		},
		functions = {{name = "inspect", parameters = {type = "object"}}},
		function_call = {name = "inspect"},
	}))
	t:eq(compat.client_options.parallel_tool_calls, false)
	t:eq(compat.client_options.tool_choice.name, "inspect")
	t:eq(compat.messages[2].tool_calls[1].id, compat.messages[3].tool_call_id)
	t:eq(compat.messages[3].role, "tool")
	---@type openai.Message
	local message = {role = "assistant", content = "", tool_calls = {{
		id = "call_new", type = "function", ["function"] = {name = "inspect", arguments = "{}"},
	}}}
	local completion = ChatCompat.createCompletion("model", message, "chatcmpl-test", 1000, true)
	t:eq(completion.choices[1].finish_reason, "function_call")
	t:eq(completion.choices[1].message.function_call.name, "inspect")
	t:eq(completion.choices[1].message.tool_calls, nil)
	local delta = ChatCompat.toolCallDelta({index = 0, id = "call_new", name = "inspect", arguments = "{}"}, true)
	t:eq(delta.function_call.arguments, "{}")
	t:eq(delta.tool_calls, nil)
	delta = ChatCompat.toolCallDelta({index = 1, id = "call_new", name = "inspect", arguments = "{}"}, false)
	t:eq(delta.tool_calls[1].index, 1)
	t:eq(delta.tool_calls[1].id, "call_new")
	t:eq(ChatCompat.terminalToolCalls(message, false).tool_calls[1].id, "call_new")
end

---@param t testing.T
function test.normalizes_chat_content_parts(t)
	local compat = assert(normalize({messages = {
		{role = "system", content = {{type = "text", text = "first"}, {type = "text", text = " second"}}},
		{role = "developer", content = {{type = "text", text = "instructions",
			prompt_cache_breakpoint = {mode = "explicit"}}}},
		{role = "user", content = {
			{type = "text", text = "inspect", prompt_cache_breakpoint = {mode = "explicit"}},
			{type = "image_url", image_url = {url = "data:image/png;base64,aGVsbG8=", detail = "high"}},
			{type = "input_audio", input_audio = {data = "aGVsbG8=", format = "wav"}},
			{type = "file", file = {file_data = "data:text/plain;base64,aGVsbG8=", filename = "hello.txt"}},
		}},
		{role = "assistant", content = {{type = "refusal", refusal = "cannot"}}},
	}}))
	t:eq(compat.messages[1].content, "first second")
	t:eq(compat.messages[2].content[1].prompt_cache_breakpoint.mode, "explicit")
	t:eq(compat.messages[3].content[1].type, "input_text")
	t:eq(compat.messages[3].content[2].type, "input_image")
	t:eq(compat.messages[3].content[3].input_audio.format, "wav")
	t:eq(compat.messages[3].content[4].filename, "hello.txt")
	t:eq(compat.messages[4].content, "cannot")
end

---@param t testing.T
function test.rejects_invalid_and_unsupported_completion_fields(t)
	---@type {[1]: {[string]: any}, [2]: string}[]
	local cases = {
		{{messages = {{role = "unsupported", content = "invalid"}}}, "invalid_messages"},
		{{reasoning_effort = "extreme"}, "invalid_reasoning_effort"},
		{{parallel_tool_calls = "yes"}, "invalid_parallel_tool_calls"},
		{{verbosity = "verbose"}, "invalid_verbosity"},
		{{temperature = 3}, "invalid_temperature"},
		{{stream_options = {include_usage = true}}, "invalid_stream_options"},
		{{max_completion_tokens = 0}, "invalid_max_tokens"},
		{{prompt_cache_key = ("x"):rep(65)}, "invalid_prompt_cache_key"},
		{{prompt_cache_options = {mode = "explicit", ttl = "24h"}}, "invalid_prompt_cache_options"},
		{{tool_choice = "required"}, "invalid_tool_choice"},
		{{response_format = {type = "json_schema", json_schema = {name = "missing_schema"}}}, "invalid_response_format"},
		{{functions = {{name = "inspect"}}, tools = {{type = "function", ["function"] = {name = "inspect"}}}}, "invalid_functions"},
		{{messages = {{role = "function", name = "inspect", content = "orphaned"}}}, "invalid_messages"},
		{{functions = {{name = "inspect", parameters = {type = "object"}}}, parallel_tool_calls = true}, "invalid_parallel_tool_calls"},
		{{messages = {{role = "user", content = {{type = "input_audio",
			input_audio = {data = "aGVsbG8=", format = "wav"}, prompt_cache_breakpoint = {mode = "explicit"}}}}}}, "invalid_messages"},
	}
	for _, case in ipairs(cases) do
		local body = case[1]
		if not body.messages then body.messages = {{role = "user", content = "hi"}} end
		local compat, _, code = normalize(body)
		t:eq(compat, nil)
		t:eq(code, case[2])
	end
	for _, body in ipairs({
		{n = 2}, {temperature = 0.7}, {top_p = 0.9}, {stop = "END"}, {seed = 42},
		{logprobs = true}, {top_logprobs = 5}, {frequency_penalty = 0.5},
		{presence_penalty = -0.5}, {logit_bias = {["42"] = -1}},
	}) do
		body.messages = {{role = "user", content = "hi"}}
		local compat, _, code = normalize(body)
		t:eq(compat, nil)
		t:eq(code, "unsupported_parameter")
	end
end

return test
