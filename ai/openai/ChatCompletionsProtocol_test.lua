local json = require("web.json")
local Protocol = require("ai.openai.ChatCompletionsProtocol")

local test = {}

---@param t testing.T
function test.normalizes_usage_dialects_without_mutation(t)
	t:eq(Protocol.canonicalUsage(nil), nil)
	t:eq(Protocol.canonicalUsage(json.null), nil)
	t:eq(Protocol.canonicalUsage(json.object()), nil)
	t:eq(Protocol.canonicalUsage({prompt_tokens = 5}), nil)
	local native = {input_tokens = 5, output_tokens = 6, total_tokens = 11,
		input_tokens_details = {cached_tokens = 2}}
	local before = json.encode(native)
	t:tdeq(Protocol.canonicalUsage(native), {input_tokens = 5, output_tokens = 6, cached_input_tokens = 2})
	t:eq(json.encode(native), before)
	t:tdeq(Protocol.canonicalUsage({prompt_tokens = 5, completion_tokens = 6,
		prompt_tokens_details = {cached_tokens = 1}}), {input_tokens = 5, output_tokens = 6, cached_input_tokens = 1})
	t:tdeq(Protocol.canonicalUsage({prompt_tokens = 0, completion_tokens = 0}),
		{input_tokens = 0, output_tokens = 0, cached_input_tokens = 0})
	t:tdeq(Protocol.canonicalUsage({prompt_tokens = 5, completion_tokens = 6,
		prompt_tokens_details = {cached_tokens = "unknown"}}), {input_tokens = 5, output_tokens = 6, cached_input_tokens = 0})
end

---@param t testing.T
function test.canonical_message_keeps_supported_output_only(t)
	local message = {content = "hello", reasoning_content = "thought", finish_reason = "tool_calls",
		tool_calls = {{id = "c1", type = "function", ["function"] = {name = "inspect", arguments = "{untrusted"}}},
		usage = {prompt_tokens = 5, completion_tokens = 6}, provider_metadata = "private"}
	local before = json.encode(message)
	local canonical = Protocol.canonicalMessage(message)
	t:eq(canonical.content, "hello")
	t:eq(canonical.reasoning_content, "thought")
	t:eq(canonical.tool_calls[1]["function"].arguments, "{untrusted")
	t:eq(canonical.finish_reason, "tool_calls")
	t:eq(canonical.usage.input_tokens, 5)
	t:eq(canonical.provider_metadata, nil)
	t:eq(json.encode(message), before)
	t:eq(Protocol.canonicalMessage({}).content, "")
end

---@param t testing.T
function test.completion_shapes_and_finish_reason_defaults(t)
	local usage = {input_tokens = 5, output_tokens = 6, cached_input_tokens = 2}
	local message = {content = "hello", usage = usage}
	local completion = Protocol.completion("id", 42, "public-model", message)
	t:eq(completion.id, "id")
	t:eq(completion.object, "chat.completion")
	t:eq(completion.created, 42)
	t:eq(completion.model, "public-model")
	t:eq(completion.choices[1].index, 0)
	t:eq(completion.choices[1].message.content, "hello")
	t:eq(completion.choices[1].message.role, "assistant")
	t:eq(completion.choices[1].message.usage, nil)
	t:eq(completion.choices[1].message.wire_usage, nil)
	t:eq(completion.choices[1].message.finish_reason, nil)
	t:eq(completion.choices[1].finish_reason, "stop")
	t:eq(completion.usage.total_tokens, 11)
	t:eq(completion.usage.prompt_tokens_details.cached_tokens, 2)
	t:eq(Protocol.finishReason({tool_calls = {{id = "c1"}}}), "tool_calls")
	t:eq(Protocol.finishReason({finish_reason = "length", tool_calls = {{}}}), "length")
	-- Protocol construction must not impose a provider's terminal-reason allowlist.
	t:eq(Protocol.finishReason({finish_reason = "provider-extension"}), "provider-extension")
	t:eq(Protocol.completion("id", 1, "m", {content = ""}).usage, nil)
	t:eq(Protocol.completionUsage({input_tokens = 0, output_tokens = 0, cached_input_tokens = 0}).prompt_tokens_details, nil)
end

---@param t testing.T
function test.chunks_omit_usage_or_emit_null_and_usage_only_empty_array(t)
	local delta = {reasoning_content = "thinking"}
	local chunk = Protocol.chunk("id", 42, "model", delta, nil, false)
	t:eq(chunk.object, "chat.completion.chunk")
	t:eq(chunk.model, "model")
	t:eq(chunk.created, 42)
	t:eq(chunk.choices[1].delta, delta)
	t:eq(chunk.usage, nil)
	t:eq(json.encode(chunk):find('"usage"', 1, true), nil)
	chunk = Protocol.chunk("id", 42, "model", json.object(), "stop", true)
	t:eq(chunk.choices[1].finish_reason, "stop")
	t:eq(chunk.usage, json.null)
	local usage = {prompt_tokens = 5, completion_tokens = 6, total_tokens = 11,
		completion_tokens_details = {reasoning_tokens = 4}}
	local frame = Protocol.usageChunk("id", 42, "model", usage)
	local decoded = json.decode(json.encode(frame))
	t:eq(json.isArray(decoded.choices), true)
	t:eq(#decoded.choices, 0)
	t:eq(decoded.usage.completion_tokens_details.reasoning_tokens, 4)
	t:eq(frame.usage, usage)
end

---@param t testing.T
function test.only_meaningful_deltas_are_output(t)
	for _, delta in ipairs({{}, {role = "assistant"}, {content = ""}, {content = false},
		{content = json.null}, {tool_calls = {}}, {audio = {data = ""}},
		{tool_calls = {{index = 0, id = "call_1", type = "function"}}}}) do
		t:eq(Protocol.hasOutput(delta), false)
	end
	for _, delta in ipairs({{content = "hi"}, {reasoning_content = "thinking"}, {reasoning = "thought"},
		{refusal = "no"}, {tool_calls = {{["function"] = {name = "inspect"}}}},
		{tool_calls = {{index = 0, ["function"] = {arguments = "{}"}}}},
		{function_call = {arguments = "{}"}}, {audio = {data = "encoded"}}}) do
		t:eq(Protocol.hasOutput(delta), true)
	end
end

---@param t testing.T
function test.reasoning_fields_are_independent_and_keep_json_values(t)
	for _, fields in ipairs({{reasoning = "raw"}, {reasoning_content = "legacy"},
		{reasoning = "same", reasoning_content = "same"},
		{reasoning = "one", reasoning_content = "two"},
		{reasoning = json.null, reasoning_content = ""},
		{reasoning = json.array({{type = "opaque", data = "not text"}})}}) do
		local before = json.encode(fields)
		local canonical = Protocol.canonicalMessage(fields)
		local wire = Protocol.completion("id", 1, "m", canonical).choices[1].message
		t:eq(wire.reasoning == nil, fields.reasoning == nil)
		t:eq(wire.reasoning_content == nil, fields.reasoning_content == nil)
		t:eq(json.encode(wire.reasoning), json.encode(fields.reasoning))
		t:eq(json.encode(wire.reasoning_content), json.encode(fields.reasoning_content))
		t:eq(json.encode(fields), before)
	end
	local message = Protocol.canonicalMessage({refusal = "no", finish_reason = "length"})
	local completion = Protocol.completion("id", 1, "m", message)
	t:eq(completion.choices[1].message.refusal, "no")
	t:eq(completion.choices[1].finish_reason, "length")
end

---@param t testing.T
function test.reported_usage_details_are_separate_from_accounting_and_not_invented(t)
	for _, reasoning in ipairs({false, 0, 4}) do
		local raw = {prompt_tokens = 5, completion_tokens = 6, total_tokens = 11,
			prompt_tokens_details = json.object({cached_tokens = 0, audio_tokens = 2}),
			completion_tokens_details = json.object({accepted_prediction_tokens = 1}),
			private_metadata = "must not leak"}
		if reasoning ~= false then raw.completion_tokens_details.reasoning_tokens = reasoning end
		local before = json.encode(raw)
		local message = Protocol.canonicalMessage({content = "answer", usage = {prompt_tokens = 99, completion_tokens = 99}}, raw)
		t:tdeq(message.usage, {input_tokens = 5, output_tokens = 6, cached_input_tokens = 0})
		local wire = Protocol.completion("id", 1, "m", message)
		t:eq(wire.usage.prompt_tokens_details.cached_tokens, 0)
		t:eq(wire.usage.prompt_tokens_details.audio_tokens, 2)
		t:eq(wire.usage.completion_tokens_details.reasoning_tokens, reasoning ~= false and reasoning or nil)
		t:eq(wire.usage.completion_tokens_details.accepted_prediction_tokens, 1)
		t:eq(wire.usage.completion_tokens, 6)
		t:eq(wire.usage.total_tokens, 11)
		t:eq(wire.usage.private_metadata, nil)
		t:eq(wire.choices[1].message.wire_usage, nil)
		t:eq(json.encode(raw), before)
	end
	for _, details in ipairs({json.null, json.object()}) do
		local message = Protocol.canonicalMessage({}, {prompt_tokens = 1, completion_tokens = 2,
			prompt_tokens_details = details, completion_tokens_details = details})
		t:eq(json.encode(message.wire_usage.prompt_tokens_details), json.encode(details))
		t:eq(json.encode(message.wire_usage.completion_tokens_details), json.encode(details))
		t:eq(message.wire_usage.total_tokens, nil)
	end
	local native = Protocol.canonicalMessage({}, {input_tokens = 5, output_tokens = 6, total_tokens = 11,
		input_tokens_details = {cached_tokens = 2}})
	t:tdeq(native.wire_usage, {prompt_tokens = 5, completion_tokens = 6, total_tokens = 11,
		prompt_tokens_details = {cached_tokens = 2}})
	local partial = Protocol.canonicalMessage({}, {completion_tokens_details = {reasoning_tokens = 0}})
	t:eq(partial.usage, nil)
	t:eq(partial.wire_usage.completion_tokens_details.reasoning_tokens, 0)
	local bare = Protocol.canonicalMessage({}, {prompt_tokens = 1, completion_tokens = 2})
	t:eq(bare.wire_usage.prompt_tokens_details, nil)
	t:eq(bare.wire_usage.completion_tokens_details, nil)
end

return test
