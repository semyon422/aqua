local json = require("web.json")
local Protocol = require("ai.zai.Protocol")

local test = {}

local function normalize(text, thinking, tool_stream)
	return Protocol.normalizeRequest(json.decode(text), {public = true}, {public = "upstream"}, thinking, tool_stream)
end

---@param t testing.T
function test.normalizes_model_messages_and_defaults_without_mutating_input(t)
	local request = json.decode([[{"model":"public","messages":[
		{"role":"developer","content":[{"type":"text","text":"be "},{"type":"input_text","text":"brief"}]},
		{"role":"user","content":"hi"}],"max_completion_tokens":16,"unknown":"not forwarded"}]])
	local before = json.encode(request)
	local body, model, stream, include_usage, err = Protocol.normalizeRequest(request,
		{public = true}, {public = "upstream"}, "disabled", true)
	t:eq(err, nil)
	t:eq(model, "public")
	t:eq(body.model, "upstream")
	t:eq(body.messages[1].role, "system")
	t:eq(body.messages[1].content, "be brief")
	t:eq(body.max_tokens, 16)
	t:eq(body.thinking.type, "disabled")
	t:eq(body.unknown, nil)
	t:eq(stream, false)
	t:eq(include_usage, false)
	t:eq(json.encode(request), before)
end

---@param t testing.T
function test.tools_thinking_response_format_and_usage(t)
	local body, _, stream, include_usage, err = normalize([[{
		"model":"public","messages":[{"role":"user","content":"hi"},
		{"role":"assistant","tool_calls":[{"id":"c1","type":"function","function":{"name":"inspect","arguments":"{not parsed"}}]},
		{"role":"tool","tool_call_id":"c1","content":"ok"}],
		"tools":[{"type":"function","function":{"name":"inspect","parameters":{}}}],
		"tool_choice":{"type":"function","function":{"name":"inspect"}},
		"thinking":{"type":"enabled","clear_thinking":false},
		"response_format":{"type":"json_schema","json_schema":{"name":"answer","schema":{},"strict":true}},
		"stream":true,"stream_options":{"include_usage":true}
	}]], "disabled", true)
	t:eq(err, nil)
	t:eq(stream, true)
	t:eq(include_usage, true)
	t:eq(body.stream_options, nil)
	t:eq(body.tool_stream, true)
	t:eq(body.messages[2].tool_calls[1]["function"].arguments, "{not parsed")
	t:eq(body.messages[3].tool_call_id, "c1")
	t:eq(body.tool_choice["function"].name, "inspect")
	t:eq(body.thinking.type, "enabled")
	t:eq(body.thinking.clear_thinking, false)
	t:eq(body.response_format.json_schema.strict, true)
end

---@param t testing.T
function test.rejects_unsupported_and_malformed_parameters(t)
	local cases = {
		{'"model":"missing"', "model_not_found"},
		{'"seed":1', "unsupported_parameter"},
		{'"messages":[]', "invalid_messages"},
		{'"tools":{}', "invalid_tools"},
		{'"tool_choice":"required"', "invalid_tool_choice"},
		{'"thinking":{"type":"unknown"}', "invalid_thinking"},
		{'"response_format":{"type":"json_schema"}', "invalid_response_format"},
		{'"stream":true,"stream_options":{"include_usage":"yes"}', "invalid_stream_options"},
		{'"stream_options":{}', "invalid_stream_options"},
		{'"max_tokens":1,"max_completion_tokens":2', "invalid_max_tokens"},
		{'"max_tokens":0', "invalid_max_tokens"},
		{'"temperature":3', "invalid_temperature"},
		{'"stop":[""]', "invalid_stop"},
	}
	for _, case in ipairs(cases) do
		local request = json.decode('{"model":"public","messages":[{"role":"user","content":"hi"}]}')
		for key, value in pairs(json.decode("{" .. case[1] .. "}")) do request[key] = value end
		local body, _, _, _, err, code = Protocol.normalizeRequest(request, {public = true}, {}, nil, true)
		t:eq(body, nil)
		t:assert(type(err) == "string")
		t:eq(code, case[2])
	end
end

---@param t testing.T
function test.rejects_non_text_content_and_invalid_tool_history(t)
	t:eq(Protocol.normalizeMessages(json.decode('[]')), nil)
	t:eq(Protocol.normalizeMessages(json.decode('[{"role":"user","content":[{"type":"image_url","image_url":{"url":"x"}}]}]')), nil)
	t:eq(Protocol.normalizeMessages(json.decode('[{"role":"tool","content":"result"}]')), nil)
	t:eq(Protocol.normalizeMessages(json.decode('[{"role":"assistant","tool_calls":[{"type":"function"}]}]')), nil)
	t:eq(Protocol.normalizeTools(json.decode('[{"type":"function","function":{"name":"x","parameters":[]}}]')), nil)
end

return test
