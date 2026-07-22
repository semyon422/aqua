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
		create_client = function(model)
			t:eq(model, "model-a")
			return {
				completeStream = function(_, messages, tools)
					seen = {messages = messages, tools = tools}
					return {
						role = "assistant",
						content = "hello",
						response_items = {{type = "reasoning", encrypted_content = "private"}},
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

	t:eq(response.status, 200)
	local decoded = json.decode(response.body)
	t:eq(seen.messages[1].content, "hi")
	t:eq(decoded.object, "chat.completion")
	t:eq(decoded.choices[1].message.content, "hello")
	t:eq(decoded.choices[1].message.response_items, nil)
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
				completeStream = function(_, _, _, on_text_delta)
					on_text_delta("Hel")
					on_text_delta("lo")
					return {
						role = "assistant",
						content = "Hello",
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
		messages = {{role = "user", content = "hi"}},
		stream = true,
	}, "proxy-secret")

	t:eq(response.status, 200)
	t:assert(response.body:find('"content":"Hel"', 1, true))
	t:assert(response.body:find('"content":"lo"', 1, true))
	t:assert(response.body:find('"finish_reason":"tool_calls"', 1, true))
	t:assert(response.body:find('"id":"call_1"', 1, true))
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
		messages = {{role = "developer", content = "unsupported"}},
	}, "proxy-secret")
	t:eq(response.status, 400)
	t:eq(json.decode(response.body).error.code, "invalid_messages")
	server:stop()
end

return test
