local ResponsesProtocol = require("ai.openai.ResponsesProtocol")
local Headers = require("web.http.Headers")
local json = require("web.json")
local digest = require("digest")

local test = {}

---@param t testing.T
function test.validates_stateless_native_input(t)
	t:eq(ResponsesProtocol.validateRequest({input = "hi"}), nil)
	t:eq(ResponsesProtocol.validateRequest({input = json.array(), store = false}), nil)
	---@type {[1]: {[string]: any}, [2]: string}[]
	local cases = {
		{{input = json.object()}, "invalid_input"},
		{{instructions = 1}, "invalid_instructions"},
		{{stream = "yes"}, "invalid_stream"}, {{store = true}, "unsupported_store"},
		{{background = true}, "unsupported_background"},
		{{previous_response_id = "r1"}, "unsupported_response_state"},
		{{conversation = "c1"}, "unsupported_response_state"},
		{{reasoning = "high"}, "invalid_reasoning"},
		{{reasoning = json.object({effort = 1})}, "invalid_reasoning"},
		{{text = "json"}, "invalid_text"}, {{include = "usage"}, "invalid_include"},
		{{include = json.array({1})}, "invalid_include"}, {{tools = "tool"}, "invalid_tools"},
		{{parallel_tool_calls = "yes"}, "invalid_parallel_tool_calls"},
		{{prompt_cache_key = ""}, "invalid_prompt_cache_key"},
		{{prompt_cache_key = ("x"):rep(65)}, "invalid_prompt_cache_key"},
	}
	for _, case in ipairs(cases) do
		if case[1].input == nil then case[1].input = "hi" end
		local message, code = ResponsesProtocol.validateRequest(case[1])
		t:assert(message)
		t:eq(code, case[2])
	end
end

---@param t testing.T
function test.affinity_is_stable_validated_and_prioritized(t)
	local headers = Headers():set("x-session-affinity", "thread"):set("session_id", "other")
		:set("x-client-request-id", "request")
	local session, err, source = ResponsesProtocol.getSessionAffinity({headers = headers})
	t:eq(session, "thread")
	t:eq(err, nil)
	t:eq(source, "x-session-affinity")
	t:eq(ResponsesProtocol.cacheSessionId("key"), digest.hash("sha256", "key", true))
	t:eq(ResponsesProtocol.cacheSessionId(nil), nil)
	for _, value in ipairs({"", "bad header", ("x"):rep(129)}) do
		session, err = ResponsesProtocol.getSessionAffinity({headers = Headers():set("session_id", value)})
		t:eq(session, nil)
		t:assert(err)
	end
	headers = Headers():add("session_id", "one"):add("session_id", "two")
	session, err = ResponsesProtocol.getSessionAffinity({headers = headers})
	t:eq(session, nil)
	t:assert(err)
end

return test
