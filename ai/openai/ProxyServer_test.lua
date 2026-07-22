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
		prompt_cache_key = "zed-thread",
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
	t:eq(decoded.choices[1].message.reasoning_content, "brief thought")
	t:eq(decoded.choices[1].message.response_items, nil)
	t:eq(decoded.usage.prompt_tokens, 12)
	t:eq(decoded.usage.completion_tokens, 5)
	t:eq(decoded.usage.total_tokens, 17)
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
			{role = "developer", content = "instructions"},
			{role = "user", content = {
				{type = "text", text = "inspect these"},
				{type = "image_url", image_url = {url = "data:image/png;base64,aGVsbG8=", detail = "high"}},
				{type = "input_audio", input_audio = {data = "aGVsbG8=", format = "wav"}},
				{type = "file", file = {file_data = "data:text/plain;base64,aGVsbG8=", filename = "hello.txt"}},
			}},
			{role = "assistant", content = {{type = "refusal", refusal = "cannot"}}},
		},
	}, "proxy-secret")

	t:eq(response.status, 200)
	t:eq(seen_messages[1].role, "developer")
	t:eq(seen_messages[2].content[1].type, "input_text")
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
	server:stop()
end

return test
