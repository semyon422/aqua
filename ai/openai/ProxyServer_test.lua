local coext = require("coext")
local socket = require("socket")

local CosocketScheduler = require("web.luasocket.CosocketScheduler")
local http_util = require("web.http.util")
local json = require("web.json")
local ProxyServer = require("ai.openai.ProxyServer")

local test = {}

---@param t testing.T
---@param scheduler web.CosocketScheduler
---@param thread thread
local function pump(t, scheduler, thread)
	local deadline = socket.gettime() + 2
	while coroutine.status(thread) ~= "dead" do
		local ok, err = scheduler:update(0.01)
		if not ok and err then error(err) end
		t:assert(socket.gettime() < deadline)
	end
end

---@param t testing.T
---@param scheduler web.CosocketScheduler
---@param port integer
---@param path string
---@param body table?
---@param token string?
---@return {status: integer, body: string}
local function request(t, scheduler, port, path, body, token)
	local response
	local request_err
	local headers = {}
	if token then headers.Authorization = "Bearer " .. token end
	local options = {
		method = body and "POST" or "GET",
		headers = headers,
		scheduler = scheduler,
		timeout = 1,
	}
	local thread = coext.detach(coroutine.create(function()
		response, request_err = http_util.request(
			("http://127.0.0.1:%d%s"):format(port, path),
			body and json.encode(body) or nil,
			options
		)
	end))
	t:assert(coroutine.resume(thread))
	pump(t, scheduler, thread)
	t:eq(request_err, nil)
	return assert(response)
end

---@param t testing.T
---@param scheduler web.CosocketScheduler
---@param port integer
---@param body table
---@param token string
---@return {status: integer, body: string}
local function chunkedRequest(t, scheduler, port, body, token)
	local response
	local request_err
	local thread = coext.detach(coroutine.create(function()
		response, request_err = http_util.request(
			("http://127.0.0.1:%d/v1/chat/completions"):format(port),
			nil,
			{
				method = "POST",
				headers = {Authorization = "Bearer " .. token, ["Content-Type"] = "application/json"},
				request_chunks = {json.encode(body)},
				scheduler = scheduler,
				timeout = 1,
			}
		)
	end))
	t:assert(coroutine.resume(thread))
	pump(t, scheduler, thread)
	t:eq(request_err, nil)
	return assert(response)
end

---@param t testing.T
function test.authenticates_and_lists_configured_models(t)
	local scheduler = CosocketScheduler()
	local logs = {}
	local server = ProxyServer({
		scheduler = scheduler,
		users = {{name = "alice", access_token = "proxy-secret"}},
		models = {"model-a", "model-b"},
		create_client = function() error("not used") end,
		logger = function(line) table.insert(logs, line) end,
	})
	t:assert(server:start("127.0.0.1", 0))
	local _, port = server:getAddress()

	local response = request(t, scheduler, assert(port), "/v1/models", nil, nil)
	t:eq(response.status, 401)
	t:eq(json.decode(response.body).error.code, "invalid_api_key")

	response = request(t, scheduler, port, "/v1/models", nil, "proxy-secret")
	t:eq(response.status, 200)
	local decoded = json.decode(response.body)
	t:eq(decoded.data[1].id, "model-a")
	t:eq(decoded.data[2].id, "model-b")
	t:assert(logs[2]:find("user=alice", 1, true))
	t:eq(logs[2]:find("proxy-secret", 1, true), nil)
	server:stop()
end

---@param t testing.T
function test.proxies_non_streaming_native_response(t)
	local scheduler = CosocketScheduler()
	local seen_request
	local server = ProxyServer({
		scheduler = scheduler,
		users = {{name = "alice", access_token = "proxy-secret"}},
		models = {"model-a"},
		create_client = function(model, reasoning_effort, request_options)
			t:eq(model, "model-a")
			t:eq(reasoning_effort, "high")
			t:eq(request_options.parallel_tool_calls, false)
			t:eq(request_options.verbosity, "high")
			return {
				createResponse = function(_, request_body, on_event)
					seen_request = request_body
					t:eq(on_event, nil)
					return {
						id = "resp_1",
						object = "response",
						status = "completed",
						model = "model-a",
						output = json.array({json.object({
							type = "message",
							id = "msg_1",
							role = "assistant",
							content = json.array({json.object({type = "output_text", text = "hello", annotations = json.array()})}),
						})}),
					}
				end,
			}
		end,
		logger = function() end,
	})
	t:assert(server:start("127.0.0.1", 0))
	local _, port = server:getAddress()
	local response = request(t, scheduler, assert(port), "/v1/responses", {
		model = "model-a",
		input = "hello",
		store = false,
		stream = false,
		reasoning = {effort = "high", summary = "auto"},
		text = {verbosity = "high"},
		parallel_tool_calls = false,
	}, "proxy-secret")

	t:eq(response.status, 200)
	t:eq(seen_request.input, "hello")
	t:eq(seen_request.stream, false)
	local decoded = json.decode(response.body)
	t:eq(decoded.id, "resp_1")
	t:eq(decoded.object, "response")
	t:eq(decoded.output[1].content[1].text, "hello")
	server:stop()
end

---@param t testing.T
function test.streams_native_response_events(t)
	local scheduler = CosocketScheduler()
	local server = ProxyServer({
		scheduler = scheduler,
		users = {{name = "alice", access_token = "proxy-secret"}},
		models = {"model-a"},
		create_client = function()
			return {
				createResponse = function(_, _, on_event)
					local response = {id = "resp_1", object = "response", status = "in_progress", output = json.array()}
					t:assert(on_event({type = "response.created", response = response}) ~= false)
					t:assert(on_event({type = "response.output_text.delta", item_id = "msg_1",
						output_index = 0, content_index = 0, delta = "hello"}) ~= false)
					response.status = "completed"
					t:assert(on_event({type = "response.completed", response = response}) ~= false)
					return response
				end,
			}
		end,
		logger = function() end,
	})
	t:assert(server:start("127.0.0.1", 0))
	local _, port = server:getAddress()
	local response = request(t, scheduler, assert(port), "/v1/responses", {
		model = "model-a",
		input = json.array({json.object({role = "user", content = "hello"})}),
		store = false,
		stream = true,
	}, "proxy-secret")

	t:eq(response.status, 200)
	t:assert(response.body:find("event: response.created", 1, true))
	t:assert(response.body:find('"type":"response.output_text.delta"', 1, true))
	t:assert(response.body:find('"delta":"hello"', 1, true))
	t:assert(response.body:find("event: response.completed", 1, true))
	t:assert(not response.body:find("[DONE]", 1, true))
	server:stop()
end

---@param t testing.T
function test.translates_non_streaming_completion_and_hides_subscription_items(t)
	local scheduler = CosocketScheduler()
	local seen
	local server = ProxyServer({
		scheduler = scheduler,
		users = {{name = "alice", access_token = "proxy-secret"}},
		models = {"model-a"},
		create_client = function(model, reasoning_effort, request_options)
			t:eq(model, "model-a")
			t:eq(reasoning_effort, "high")
			t:eq(request_options.parallel_tool_calls, false)
			t:eq(request_options.verbosity, "high")
			t:eq(request_options.prompt_cache_key, "zed-thread")
			t:eq(request_options.prompt_cache_options.mode, "explicit")
			t:eq(request_options.prompt_cache_options.ttl, "30m")
			t:eq(request_options.tool_choice.type, "function")
			t:eq(request_options.tool_choice.name, "inspect")
			t:eq(request_options.text_format.type, "json_schema")
			t:eq(request_options.text_format.name, "answer")
			t:eq(request_options.text_format.schema.type, "object")
			return {
				completeStream = function(_, messages, tools)
					seen = {messages = messages, tools = tools}
					return {
						role = "assistant",
						content = "hello",
						finish_reason = "length",
						reasoning_content = "brief thought",
						response_items = {{type = "reasoning", encrypted_content = "private"}},
						usage = {input_tokens = 12, output_tokens = 5, total_tokens = 17},
					}
				end,
			}
		end,
		logger = function() end,
	})
	t:assert(server:start("127.0.0.1", 0))
	local _, port = server:getAddress()
	local response = request(t, scheduler, assert(port), "/v1/chat/completions", {
		model = "model-a",
		messages = {{role = "user", content = "hi"}},
		reasoning_effort = "high",
		max_completion_tokens = 2048,
		parallel_tool_calls = false,
		verbosity = "high",
		temperature = 1,
		top_p = 1,
		n = 1,
		stop = {},
		logprobs = false,
		frequency_penalty = 0,
		presence_penalty = 0,
		logit_bias = json.object(),
		prompt_cache_key = "zed-thread",
		prompt_cache_options = {mode = "explicit", ttl = "30m"},
		tools = {{type = "function", ["function"] = {
			name = "inspect", parameters = {type = "object"},
		}}},
		tool_choice = {type = "function", ["function"] = {name = "inspect"}},
		response_format = {type = "json_schema", json_schema = {
			name = "answer", schema = {type = "object"}, strict = true,
		}},
	}, "proxy-secret")

	t:eq(response.status, 200)
	local decoded = json.decode(response.body)
	t:eq(seen.messages[1].content, "hi")
	t:eq(decoded.object, "chat.completion")
	t:eq(decoded.choices[1].message.content, "hello")
	t:eq(decoded.choices[1].finish_reason, "length")
	t:eq(decoded.choices[1].message.reasoning_content, "brief thought")
	t:eq(decoded.choices[1].message.response_items, nil)
	t:eq(decoded.usage.prompt_tokens, 12)
	t:eq(decoded.usage.completion_tokens, 5)
	t:eq(decoded.usage.total_tokens, 17)
	server:stop()
end

---@param t testing.T
function test.translates_legacy_function_requests_and_history(t)
	local scheduler = CosocketScheduler()
	local seen
	local server = ProxyServer({
		scheduler = scheduler,
		users = {{name = "alice", access_token = "proxy-secret"}},
		models = {"model-a"},
		create_client = function(_, _, request_options)
			t:eq(request_options.parallel_tool_calls, false)
			t:eq(request_options.tool_choice.type, "function")
			t:eq(request_options.tool_choice.name, "inspect")
			return {
				completeStream = function(_, messages, tools)
					seen = {messages = messages, tools = tools}
					return {
						role = "assistant",
						content = "",
						finish_reason = "tool_calls",
						tool_calls = {{
							id = "call_new",
							type = "function",
							["function"] = {name = "inspect", arguments = [[{"path":"next"}]]},
						}},
					}
				end,
			}
		end,
		logger = function() end,
	})
	t:assert(server:start("127.0.0.1", 0))
	local _, port = server:getAddress()
	local response = request(t, scheduler, assert(port), "/v1/chat/completions", {
		model = "model-a",
		messages = {
			{role = "user", content = "inspect"},
			{role = "assistant", content = json.null,
				function_call = {name = "inspect", arguments = [[{"path":"old"}]]}},
			{role = "function", name = "inspect", content = "old result"},
			{role = "user", content = "continue"},
		},
		functions = {{name = "inspect", description = "Inspect", parameters = {type = "object"}}},
		function_call = {name = "inspect"},
	}, "proxy-secret")

	t:eq(response.status, 200)
	t:eq(seen.tools[1].type, "function")
	t:eq(seen.tools[1]["function"].name, "inspect")
	t:eq(seen.messages[2].tool_calls[1].id, seen.messages[3].tool_call_id)
	t:eq(seen.messages[3].role, "tool")
	t:eq(seen.messages[3].content, "old result")
	local decoded = json.decode(response.body)
	t:eq(decoded.choices[1].message.function_call.name, "inspect")
	t:eq(decoded.choices[1].message.function_call.arguments, [[{"path":"next"}]])
	t:eq(decoded.choices[1].message.tool_calls, nil)
	t:eq(decoded.choices[1].finish_reason, "function_call")
	server:stop()
end

---@param t testing.T
function test.streams_preserved_completion_finish_reason(t)
	local scheduler = CosocketScheduler()
	local server = ProxyServer({
		scheduler = scheduler,
		users = {{name = "alice", access_token = "proxy-secret"}},
		models = {"model-a"},
		create_client = function()
			return {
				completeStream = function(_, _, _, on_text_delta)
					on_text_delta("Partial")
					return {role = "assistant", content = "Partial", finish_reason = "length"}
				end,
			}
		end,
		logger = function() end,
	})
	t:assert(server:start("127.0.0.1", 0))
	local _, port = server:getAddress()
	local response = request(t, scheduler, assert(port), "/v1/chat/completions", {
		model = "model-a",
		messages = {{role = "user", content = "hi"}},
		stream = true,
	}, "proxy-secret")

	t:eq(response.status, 200)
	t:assert(response.body:find('"content":"Partial"', 1, true))
	t:assert(response.body:find('"finish_reason":"length"', 1, true))
	t:assert(response.body:find("data: [DONE]", 1, true))
	server:stop()
end

---@param t testing.T
function test.enforces_public_proxy_resource_limits(t)
	local now = 10
	local scheduler = CosocketScheduler()
	local server = ProxyServer({
		scheduler = scheduler,
		users = {{name = "alice", access_token = "proxy-secret"}},
		models = {"model-a"},
		create_client = function() error("not used") end,
		max_clients = 8,
		max_concurrent_requests_per_user = 1,
		max_requests_per_minute = 1,
		get_time = function() return now end,
		logger = function() end,
	})
	t:eq(server.http_server.tcp_server.options.max_clients, 8)
	t:assert(server:acquireRequest("proxy-secret"))
	t:eq(server:acquireRequest("proxy-secret"), false)
	server:releaseRequest("proxy-secret")
	t:assert(server:acquireRequest("proxy-secret"))
	server:releaseRequest("proxy-secret")
	t:assert(server:start("127.0.0.1", 0))
	local _, port = server:getAddress()
	local response = request(t, scheduler, assert(port), "/v1/models", nil, "proxy-secret")
	t:eq(response.status, 200)
	response = request(t, scheduler, port, "/v1/models", nil, "proxy-secret")
	t:eq(response.status, 429)
	t:eq(json.decode(response.body).error.code, "rate_limit_exceeded")
	now = now + 60
	response = request(t, scheduler, port, "/v1/models", nil, "proxy-secret")
	t:eq(response.status, 200)
	server:stop()
end

---@param t testing.T
function test.rejects_chunked_request_bodies(t)
	local scheduler = CosocketScheduler()
	local server = ProxyServer({
		scheduler = scheduler,
		users = {{name = "alice", access_token = "proxy-secret"}},
		models = {"model-a"},
		create_client = function() error("not used") end,
		logger = function() end,
	})
	t:assert(server:start("127.0.0.1", 0))
	local _, port = server:getAddress()
	local response = chunkedRequest(t, scheduler, assert(port), {
		model = "model-a",
		messages = {{role = "user", content = "hi"}},
	}, "proxy-secret")
	t:eq(response.status, 400)
	t:eq(json.decode(response.body).error.code, "unsupported_transfer_encoding")
	server:stop()
end

---@param t testing.T
function test.normalizes_openai_text_content_parts(t)
	local scheduler = CosocketScheduler()
	local seen_messages
	local server = ProxyServer({
		scheduler = scheduler,
		users = {{name = "alice", access_token = "proxy-secret"}},
		models = {"model-a"},
		create_client = function(_, _, request_options)
			t:eq(request_options.parallel_tool_calls, true)
			return {
				completeStream = function(_, messages)
					seen_messages = messages
					return {role = "assistant", content = "ok"}
				end,
			}
		end,
		logger = function() end,
	})
	t:assert(server:start("127.0.0.1", 0))
	local _, port = server:getAddress()
	local response = request(t, scheduler, assert(port), "/v1/chat/completions", {
		model = "model-a",
		messages = {
			{role = "system", content = {{type = "text", text = "first"}, {type = "text", text = " second"}}},
			{role = "user", content = {{type = "text", text = "hello"}}},
		},
	}, "proxy-secret")

	t:eq(response.status, 200)
	t:eq(seen_messages[1].content, "first second")
	t:eq(seen_messages[2].content, "hello")
	server:stop()
end

---@param t testing.T
function test.normalizes_all_chat_completion_content_parts(t)
	local scheduler = CosocketScheduler()
	local seen_messages
	local server = ProxyServer({
		scheduler = scheduler,
		users = {{name = "alice", access_token = "proxy-secret"}},
		models = {"model-a"},
		create_client = function()
			return {
				completeStream = function(_, messages)
					seen_messages = messages
					return {role = "assistant", content = "ok"}
				end,
			}
		end,
		logger = function() end,
	})
	t:assert(server:start("127.0.0.1", 0))
	local _, port = server:getAddress()
	local response = request(t, scheduler, assert(port), "/v1/chat/completions", {
		model = "model-a",
		messages = {
			{role = "developer", content = {{type = "text", text = "instructions",
				prompt_cache_breakpoint = {mode = "explicit"}}}},
			{role = "user", content = {
				{type = "text", text = "inspect these", prompt_cache_breakpoint = {mode = "explicit"}},
				{type = "image_url", image_url = {url = "data:image/png;base64,aGVsbG8=", detail = "high"}},
				{type = "input_audio", input_audio = {data = "aGVsbG8=", format = "wav"}},
				{type = "file", file = {file_data = "data:text/plain;base64,aGVsbG8=", filename = "hello.txt"}},
			}},
			{role = "assistant", content = {{type = "refusal", refusal = "cannot"}}},
		},
	}, "proxy-secret")

	t:eq(response.status, 200)
	t:eq(seen_messages[1].role, "developer")
	t:eq(seen_messages[1].content[1].prompt_cache_breakpoint.mode, "explicit")
	t:eq(seen_messages[2].content[1].type, "input_text")
	t:eq(seen_messages[2].content[1].prompt_cache_breakpoint.mode, "explicit")
	t:eq(seen_messages[2].content[2].type, "input_image")
	t:eq(seen_messages[2].content[2].detail, "high")
	t:eq(seen_messages[2].content[3].type, "input_audio")
	t:eq(seen_messages[2].content[3].input_audio.format, "wav")
	t:eq(seen_messages[2].content[4].type, "input_file")
	t:eq(seen_messages[2].content[4].filename, "hello.txt")
	t:eq(seen_messages[3].content, "cannot")
	server:stop()
end

---@param t testing.T
function test.streams_chat_completion_chunks_and_tool_calls(t)
	local scheduler = CosocketScheduler()
	local server = ProxyServer({
		scheduler = scheduler,
		users = {{name = "alice", access_token = "proxy-secret"}},
		models = {"model-a"},
		create_client = function()
			return {
				completeStream = function(_, _, _, on_text_delta, on_reasoning_delta, on_tool_call_delta)
					on_reasoning_delta("Thinking")
					on_text_delta("Hel")
					on_text_delta("lo")
					on_tool_call_delta({index = 0, id = "call_1", name = "inspect", arguments = ""})
					on_tool_call_delta({index = 0, arguments = [[{"path":"game"}]]})
					on_tool_call_delta({index = 1, id = "call_2", name = "inspect", arguments = ""})
					on_tool_call_delta({index = 1, arguments = [[{"path":"aqua"}]]})
					return {
						role = "assistant",
						content = "Hello",
						usage = {
							input_tokens = 120,
							output_tokens = 30,
							total_tokens = 150,
							input_tokens_details = {cached_tokens = 80},
							output_tokens_details = {reasoning_tokens = 20},
						},
						tool_calls = {{
							id = "call_1",
							type = "function",
							["function"] = {name = "inspect", arguments = [[{"path":"game"}]]},
						}, {
							id = "call_2",
							type = "function",
							["function"] = {name = "inspect", arguments = [[{"path":"aqua"}]]},
						}},
					}
				end,
			}
		end,
		logger = function() end,
	})
	t:assert(server:start("127.0.0.1", 0))
	local _, port = server:getAddress()
	local response = request(t, scheduler, assert(port), "/v1/chat/completions", {
		model = "model-a",
		messages = {{role = "user", content = "hi"}},
		stream = true,
		stream_options = {include_usage = true},
	}, "proxy-secret")

	t:eq(response.status, 200)
	t:assert(response.body:find('"content":"Hel"', 1, true))
	t:assert(response.body:find('"content":"lo"', 1, true))
	t:assert(response.body:find('"reasoning_content":"Thinking"', 1, true))
	t:assert(response.body:find('"finish_reason":"tool_calls"', 1, true))
	t:assert(response.body:find('"delta":{}', 1, true))
	t:assert(not response.body:find('"delta":[]', 1, true))
	t:assert(response.body:find('"id":"call_1"', 1, true))
	t:assert(response.body:find('"id":"call_2"', 1, true))
	t:assert(response.body:find('"index":1', 1, true))
	t:assert(response.body:find('"arguments":"{\\\"path\\\":\\\"game\\\"}"', 1, true))
	t:assert(response.body:find('"choices":[],"created":', 1, true))
	t:assert(response.body:find('"completion_tokens":30', 1, true))
	t:assert(response.body:find('"prompt_tokens":120', 1, true))
	t:assert(response.body:find('"cached_tokens":80', 1, true))
	t:assert(response.body:find('"reasoning_tokens":20', 1, true))
	t:assert(response.body:find("data: [DONE]", 1, true))
	server:stop()
end

---@param t testing.T
function test.streams_legacy_function_call_chunks(t)
	local scheduler = CosocketScheduler()
	local server = ProxyServer({
		scheduler = scheduler,
		users = {{name = "alice", access_token = "proxy-secret"}},
		models = {"model-a"},
		create_client = function()
			return {
				completeStream = function(_, _, _, _, _, on_tool_call_delta)
					on_tool_call_delta({index = 0, id = "call_1", name = "inspect", arguments = ""})
					on_tool_call_delta({index = 0, arguments = [[{"path":"game"}]]})
					return {
						role = "assistant",
						content = "",
						finish_reason = "tool_calls",
						tool_calls = {{
							id = "call_1",
							type = "function",
							["function"] = {name = "inspect", arguments = [[{"path":"game"}]]},
						}},
					}
				end,
			}
		end,
		logger = function() end,
	})
	t:assert(server:start("127.0.0.1", 0))
	local _, port = server:getAddress()
	local response = request(t, scheduler, assert(port), "/v1/chat/completions", {
		model = "model-a",
		messages = {{role = "user", content = "inspect"}},
		functions = {{name = "inspect", parameters = {type = "object"}}},
		stream = true,
	}, "proxy-secret")

	t:eq(response.status, 200)
	t:assert(response.body:find('"function_call":{', 1, true))
	t:assert(response.body:find('"name":"inspect"', 1, true))
	t:assert(response.body:find('"arguments":"{\\"path\\":\\"game\\"}"', 1, true))
	t:assert(response.body:find('"finish_reason":"function_call"', 1, true))
	t:assert(not response.body:find('"tool_calls"', 1, true))
	server:stop()
end

---@param t testing.T
function test.preserves_sanitized_upstream_errors(t)
	local scheduler = CosocketScheduler()
	local server = ProxyServer({
		scheduler = scheduler,
		users = {{name = "alice", access_token = "proxy-secret"}},
		models = {"model-a"},
		create_client = function()
			return {
				completeStream = function(_, _, _, on_text_delta)
					if on_text_delta then on_text_delta("partial") end
					return nil, "internal detail", {
						status = 429,
						message = "rate limited",
						type = "rate_limit_error",
						code = "rate_limit_exceeded",
						request_id = "req_123",
					}
				end,
			}
		end,
		logger = function() end,
	})
	t:assert(server:start("127.0.0.1", 0))
	local _, port = server:getAddress()
	local response = request(t, scheduler, assert(port), "/v1/chat/completions", {
		model = "model-a",
		messages = {{role = "user", content = "hi"}},
	}, "proxy-secret")
	t:eq(response.status, 429)
	t:eq(response.headers:get("x-request-id"), "req_123")
	local decoded = json.decode(response.body)
	t:eq(decoded.error.message, "rate limited")
	t:eq(decoded.error.type, "rate_limit_error")
	t:eq(decoded.error.code, "rate_limit_exceeded")
	t:eq(decoded.error.request_id, "req_123")

	response = request(t, scheduler, port, "/v1/chat/completions", {
		model = "model-a",
		messages = {{role = "user", content = "hi"}},
		stream = true,
	}, "proxy-secret")
	t:eq(response.status, 200)
	t:assert(response.body:find('"content":"partial"', 1, true))
	t:assert(response.body:find('"code":"rate_limit_exceeded"', 1, true))
	t:assert(response.body:find('"request_id":"req_123"', 1, true))
	t:assert(response.body:find("data: [DONE]", 1, true))
	server:stop()
end

---@param t testing.T
function test.rejects_unavailable_models_and_invalid_message_shapes(t)
	local scheduler = CosocketScheduler()
	local server = ProxyServer({
		scheduler = scheduler,
		users = {{name = "alice", access_token = "proxy-secret"}},
		models = {"model-a"},
		create_client = function() error("not used") end,
		logger = function() end,
	})
	t:assert(server:start("127.0.0.1", 0))
	local _, port = server:getAddress()
	local response = request(t, scheduler, assert(port), "/v1/chat/completions", {
		model = "other",
		messages = {{role = "user", content = "hi"}},
	}, "proxy-secret")
	t:eq(response.status, 400)
	t:eq(json.decode(response.body).error.code, "model_not_found")

	response = request(t, scheduler, port, "/v1/chat/completions", {
		model = "model-a",
		messages = {{role = "unsupported", content = "invalid"}},
	}, "proxy-secret")
	t:eq(response.status, 400)
	t:eq(json.decode(response.body).error.code, "invalid_messages")

	response = request(t, scheduler, port, "/v1/chat/completions", {
		model = "model-a",
		messages = {{role = "user", content = "hi"}},
		reasoning_effort = "extreme",
	}, "proxy-secret")
	t:eq(response.status, 400)
	t:eq(json.decode(response.body).error.code, "invalid_reasoning_effort")

	response = request(t, scheduler, port, "/v1/chat/completions", {
		model = "model-a",
		messages = {{role = "user", content = "hi"}},
		parallel_tool_calls = "yes",
	}, "proxy-secret")
	t:eq(response.status, 400)
	t:eq(json.decode(response.body).error.code, "invalid_parallel_tool_calls")

	response = request(t, scheduler, port, "/v1/chat/completions", {
		model = "model-a",
		messages = {{role = "user", content = "hi"}},
		verbosity = "verbose",
	}, "proxy-secret")
	t:eq(response.status, 400)
	t:eq(json.decode(response.body).error.code, "invalid_verbosity")

	response = request(t, scheduler, port, "/v1/chat/completions", {
		model = "model-a",
		messages = {{role = "user", content = "hi"}},
		temperature = 3,
	}, "proxy-secret")
	t:eq(response.status, 400)
	t:eq(json.decode(response.body).error.code, "invalid_temperature")

	for _, unsupported in ipairs({
		{n = 2},
		{temperature = 0.7},
		{top_p = 0.9},
		{stop = "END"},
		{seed = 42},
		{logprobs = true},
		{top_logprobs = 5},
		{frequency_penalty = 0.5},
		{presence_penalty = -0.5},
		{logit_bias = {["42"] = -1}},
	}) do
		unsupported.model = "model-a"
		unsupported.messages = {{role = "user", content = "hi"}}
		response = request(t, scheduler, port, "/v1/chat/completions", unsupported, "proxy-secret")
		t:eq(response.status, 400)
		t:eq(json.decode(response.body).error.code, "unsupported_parameter")
	end

	response = request(t, scheduler, port, "/v1/chat/completions", {
		model = "model-a",
		messages = {{role = "user", content = "hi"}},
		stream_options = {include_usage = true},
	}, "proxy-secret")
	t:eq(response.status, 400)
	t:eq(json.decode(response.body).error.code, "invalid_stream_options")

	response = request(t, scheduler, port, "/v1/chat/completions", {
		model = "model-a",
		messages = {{role = "user", content = "hi"}},
		max_completion_tokens = 0,
	}, "proxy-secret")
	t:eq(response.status, 400)
	t:eq(json.decode(response.body).error.code, "invalid_max_tokens")

	response = request(t, scheduler, port, "/v1/chat/completions", {
		model = "model-a",
		messages = {{role = "user", content = "hi"}},
		prompt_cache_key = ("x"):rep(65),
	}, "proxy-secret")
	t:eq(response.status, 400)
	t:eq(json.decode(response.body).error.code, "invalid_prompt_cache_key")

	response = request(t, scheduler, port, "/v1/chat/completions", {
		model = "model-a",
		messages = {{role = "user", content = "hi"}},
		prompt_cache_options = {mode = "explicit", ttl = "24h"},
	}, "proxy-secret")
	t:eq(response.status, 400)
	t:eq(json.decode(response.body).error.code, "invalid_prompt_cache_options")

	response = request(t, scheduler, port, "/v1/chat/completions", {
		model = "model-a",
		messages = {{role = "user", content = {{
			type = "input_audio",
			input_audio = {data = "aGVsbG8=", format = "wav"},
			prompt_cache_breakpoint = {mode = "explicit"},
		}}}},
	}, "proxy-secret")
	t:eq(response.status, 400)
	t:eq(json.decode(response.body).error.code, "invalid_messages")

	response = request(t, scheduler, port, "/v1/chat/completions", {
		model = "model-a",
		messages = {{role = "user", content = "hi"}},
		tool_choice = "required",
	}, "proxy-secret")
	t:eq(response.status, 400)
	t:eq(json.decode(response.body).error.code, "invalid_tool_choice")

	response = request(t, scheduler, port, "/v1/chat/completions", {
		model = "model-a",
		messages = {{role = "user", content = "hi"}},
		response_format = {type = "json_schema", json_schema = {name = "missing_schema"}},
	}, "proxy-secret")
	t:eq(response.status, 400)
	t:eq(json.decode(response.body).error.code, "invalid_response_format")

	response = request(t, scheduler, port, "/v1/chat/completions", {
		model = "model-a",
		messages = {{role = "user", content = "hi"}},
		functions = {{name = "inspect", parameters = {type = "object"}}},
		tools = {{type = "function", ["function"] = {name = "inspect", parameters = {type = "object"}}}},
	}, "proxy-secret")
	t:eq(response.status, 400)
	t:eq(json.decode(response.body).error.code, "invalid_functions")

	response = request(t, scheduler, port, "/v1/chat/completions", {
		model = "model-a",
		messages = {{role = "function", name = "inspect", content = "orphaned"}},
	}, "proxy-secret")
	t:eq(response.status, 400)
	t:eq(json.decode(response.body).error.code, "invalid_messages")

	response = request(t, scheduler, port, "/v1/chat/completions", {
		model = "model-a",
		messages = {{role = "user", content = "hi"}},
		functions = {{name = "inspect", parameters = {type = "object"}}},
		parallel_tool_calls = true,
	}, "proxy-secret")
	t:eq(response.status, 400)
	t:eq(json.decode(response.body).error.code, "invalid_parallel_tool_calls")

	response = request(t, scheduler, port, "/v1/responses", {
		model = "model-a",
		input = "hi",
		store = true,
	}, "proxy-secret")
	t:eq(response.status, 400)
	t:eq(json.decode(response.body).error.code, "unsupported_store")

	response = request(t, scheduler, port, "/v1/responses", {
		model = "model-a",
		input = "hi",
		previous_response_id = "resp_1",
	}, "proxy-secret")
	t:eq(response.status, 400)
	t:eq(json.decode(response.body).error.code, "unsupported_response_state")

	response = request(t, scheduler, port, "/v1/responses", {
		model = "model-a",
		input = json.object(),
	}, "proxy-secret")
	t:eq(response.status, 400)
	t:eq(json.decode(response.body).error.code, "invalid_input")
	server:stop()
end

return test
