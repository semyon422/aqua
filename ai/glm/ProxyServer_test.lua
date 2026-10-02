local coext = require("coext")
---@type {gettime: fun(): number}
local socket = require("socket")

local CosocketScheduler = require("web.luasocket.CosocketScheduler")
local http_util = require("web.http.util")
local json = require("web.json")
local ProxyServer = require("ai.glm.ProxyServer")

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
---@return {status: integer, body: string, headers: web.Headers}
local function request(t, scheduler, port, path, body, token)
	---@type {status: integer, body: string, headers: web.Headers}?
	local response
	---@type string?
	local request_err
	local headers = {}
	if token then headers.Authorization = "Bearer " .. token end
	local thread = coext.detach(coroutine.create(function()
		response, request_err = http_util.request(
			("http://127.0.0.1:%d%s"):format(port, path),
			body and json.encode(body) or nil,
			{
				method = body and "POST" or "GET",
				headers = headers,
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

---@param body string
---@return table[] events
local function parseSse(body)
	---@type table[]
	local events = {}
	for data in body:gmatch("data: ([^\n]+)\n") do
		if data ~= "[DONE]" then
			table.insert(events, json.decode(data))
		end
	end
	return events
end

---@class glm.FakeClientState
---@field body table?
---@field completion table?
---@field message table?
---@field deltas table[]?
---@field err string?
---@field provider_error glm.ProviderError?

---@param state glm.FakeClientState
---@return glm.Client
local function fakeClient(state)
	return {
		complete = function(_, body)
			state.body = body
			if state.completion then return state.completion end
			return nil, state.err or "upstream request failed", state.provider_error
		end,
		completeStream = function(_, body, on_delta)
			state.body = body
			for _, delta in ipairs(state.deltas or {}) do
				if on_delta(delta) == false then
					return nil, "downstream response stream closed"
				end
			end
			if state.message then return state.message end
			return nil, state.err or "upstream request failed", state.provider_error
		end,
	}
end

---@param t testing.T
---@param options table
---@return glm.ProxyServer
---@return web.CosocketScheduler
local function startServer(t, options)
	local scheduler = CosocketScheduler()
	options.scheduler = scheduler
	options.users = options.users or {{name = "alice", access_token = "proxy-secret-proxy-secret-proxy"}}
	options.models = options.models or {"glm-4.7", "glm-5.3-flash"}
	options.logger = options.logger or function() end
	local server = ProxyServer(options)
	t:assert(server:start("127.0.0.1", 0))
	return server, scheduler
end

---@param t testing.T
function test.authenticates_and_rejects_unknown_routes(t)
	---@type string[]
	local logs = {}
	local server, scheduler = startServer(t, {
		create_client = function() error("not used") end,
		logger = function(line) table.insert(logs, line) end,
	})
	local _, port = server:getAddress()

	local response = request(t, scheduler, assert(port), "/v1/models", nil, nil)
	t:eq(response.status, 404)
	t:eq(json.decode(response.body).error.code, "not_found")

	response = request(t, scheduler, port, "/v1/chat/completions", {model = "glm-4.7"}, nil)
	t:eq(response.status, 401)
	t:eq(json.decode(response.body).error.code, "invalid_api_key")
	t:assert(logs[1]:find("user=-", 1, true))
	t:eq(logs[1]:find("proxy-secret", 1, true), nil)
	server:stop()
end

---@param t testing.T
function test.proxies_non_streaming_completion(t)
	---@type glm.FakeClientState
	local state = {
		completion = {
			id = "chatcmpl-upstream",
			object = "chat.completion",
			created = 1780000000,
			model = "glm-5.3",
			choices = {{
				index = 0,
				message = {role = "assistant", content = "hello", reasoning_content = "thought"},
				finish_reason = "stop",
			}},
			usage = {prompt_tokens = 3, completion_tokens = 2, total_tokens = 5},
		},
	}
	local server, scheduler = startServer(t, {
		model_redirects = {["glm-5.3-flash"] = "glm-5.3"},
		thinking = "enabled",
		create_client = function() return fakeClient(state) end,
	})
	local _, port = server:getAddress()

	local response = request(t, scheduler, port, "/v1/chat/completions", {
		model = "glm-5.3-flash",
		messages = {
			{role = "developer", content = "be brief"},
			{role = "user", content = "hi"},
		},
		max_completion_tokens = 100,
		temperature = 0.5,
	}, "proxy-secret-proxy-secret-proxy")
	t:eq(response.status, 200)
	local completion = json.decode(response.body)
	t:eq(completion.model, "glm-5.3-flash")
	t:eq(completion.choices[1].message.content, "hello")
	t:eq(completion.usage.total_tokens, 5)

	t:eq(state.body.model, "glm-5.3")
	t:eq(state.body.stream, false)
	t:eq(state.body.max_tokens, 100)
	t:eq(state.body.max_completion_tokens, nil)
	t:eq(state.body.temperature, 0.5)
	t:eq(state.body.messages[1].role, "system")
	t:eq(state.body.messages[1].content, "be brief")
	t:eq(state.body.thinking.type, "enabled")
	server:stop()
end

---@param t testing.T
function test.proxies_streaming_completion(t)
	---@type glm.FakeClientState
	local state = {
		deltas = {
			{role = "assistant", content = ""},
			{reasoning_content = "thinking"},
			{content = "he"},
			{content = "llo"},
			{tool_calls = {{index = 0, id = "call_1", type = "function", ["function"] = {name = "f", arguments = "{}"}}}},
		},
		message = {
			role = "assistant",
			content = "hello",
			tool_calls = {{id = "call_1", type = "function", ["function"] = {name = "f", arguments = "{}"}}},
			finish_reason = "tool_calls",
			usage = {prompt_tokens = 3, completion_tokens = 2, total_tokens = 5},
		},
	}
	local server, scheduler = startServer(t, {
		create_client = function() return fakeClient(state) end,
	})
	local _, port = server:getAddress()

	local response = request(t, scheduler, port, "/v1/chat/completions", {
		model = "glm-4.7",
		messages = {{role = "user", content = "hi"}},
		tools = {{
			type = "function",
			["function"] = {name = "f", parameters = {type = "object"}},
		}},
		stream = true,
		stream_options = {include_usage = true},
		thinking = {type = "disabled"},
	}, "proxy-secret-proxy-secret-proxy")
	t:eq(response.status, 200)
	t:eq(response.headers:get("Content-Type"), "text/event-stream")
	t:assert(response.body:find("data: %[DONE%]", 1, false) or response.body:find("data: [DONE]", 1, true))

	local events = parseSse(response.body)
	t:eq(events[1].choices[1].delta.role, "assistant")
	t:eq(events[1].usage, json.null)
	t:eq(events[2].choices[1].delta.reasoning_content, "thinking")
	t:eq(events[3].choices[1].delta.content, "he")
	t:eq(events[5].choices[1].delta.tool_calls[1].id, "call_1")
	t:eq(#events[#events].choices, 0)
	t:eq(events[#events].usage.total_tokens, 5)
	local finish_chunk = events[#events - 1]
	t:eq(finish_chunk.choices[1].finish_reason, "tool_calls")
	t:eq(finish_chunk.choices[1].delta.content, nil)

	t:eq(state.body.stream, true)
	t:eq(state.body.thinking.type, "disabled")
	t:eq(state.body.tool_stream, true)
	t:eq(state.body.tools[1]["function"].name, "f")
	server:stop()
end

---@param t testing.T
function test.validates_requests(t)
	---@type glm.FakeClientState
	local state = {}
	local server, scheduler = startServer(t, {
		create_client = function() return fakeClient(state) end,
	})
	local _, port = server:getAddress()
	local token = "proxy-secret-proxy-secret-proxy"

	local response = request(t, scheduler, port, "/v1/chat/completions", {
		model = "unknown-model",
		messages = {{role = "user", content = "hi"}},
	}, token)
	t:eq(response.status, 400)
	t:eq(json.decode(response.body).error.code, "model_not_found")

	response = request(t, scheduler, port, "/v1/chat/completions", {
		model = "glm-4.7",
		messages = {{role = "pirate", content = "hi"}},
	}, token)
	t:eq(response.status, 400)
	t:eq(json.decode(response.body).error.code, "invalid_messages")

	response = request(t, scheduler, port, "/v1/chat/completions", {
		model = "glm-4.7",
		messages = {{role = "user", content = "hi"}},
		seed = 1,
	}, token)
	t:eq(response.status, 400)
	t:eq(json.decode(response.body).error.code, "unsupported_parameter")

	response = request(t, scheduler, port, "/v1/chat/completions", {
		model = "glm-4.7",
		messages = {{role = "user", content = "hi"}},
		stream_options = {include_usage = true},
	}, token)
	t:eq(response.status, 400)
	t:eq(json.decode(response.body).error.code, "invalid_stream_options")

	response = request(t, scheduler, port, "/v1/chat/completions", {
		model = "glm-4.7",
		messages = {{role = "user", content = "hi"}},
		thinking = {type = "sometimes"},
	}, token)
	t:eq(response.status, 400)
	t:eq(json.decode(response.body).error.code, "invalid_thinking")

	response = request(t, scheduler, port, "/v1/chat/completions", {
		model = "glm-4.7",
		messages = {{role = "user", content = "hi"}},
		tool_choice = {type = "function", ["function"] = {name = "missing"}},
	}, token)
	t:eq(response.status, 400)
	t:eq(json.decode(response.body).error.code, "invalid_tool_choice")

	t:eq(state.body, nil)
	server:stop()
end

---@param t testing.T
function test.rejects_chunked_request_bodies(t)
	local server, scheduler = startServer(t, {
		create_client = function() error("not used") end,
	})
	local _, port = server:getAddress()

	---@type {status: integer, body: string}?
	local response
	---@type string?
	local request_err
	local thread = coext.detach(coroutine.create(function()
		response, request_err = http_util.request(
			("http://127.0.0.1:%d/v1/chat/completions"):format(assert(port)),
			nil,
			{
				method = "POST",
				headers = {
					Authorization = "Bearer proxy-secret-proxy-secret-proxy",
					["Content-Type"] = "application/json",
				},
				request_chunks = {json.encode({model = "glm-4.7", messages = {}})},
				scheduler = scheduler,
				timeout = 1,
			}
		)
	end))
	t:assert(coroutine.resume(thread))
	pump(t, scheduler, thread)
	t:eq(request_err, nil)
	t:eq(assert(response).status, 400)
	t:eq(json.decode(response.body).error.code, "unsupported_transfer_encoding")
	server:stop()
end

---@param t testing.T
function test.maps_upstream_errors(t)
	---@type glm.FakeClientState
	local state = {
		err = "Insufficient balance",
		provider_error = {
			status = 429,
			message = "Insufficient balance",
			type = "rate_limit_error",
			code = "1302",
		},
	}
	local server, scheduler = startServer(t, {
		create_client = function() return fakeClient(state) end,
	})
	local _, port = server:getAddress()

	local response = request(t, scheduler, port, "/v1/chat/completions", {
		model = "glm-4.7",
		messages = {{role = "user", content = "hi"}},
	}, "proxy-secret-proxy-secret-proxy")
	t:eq(response.status, 429)
	local error_body = json.decode(response.body).error
	t:eq(error_body.code, "1302")
	t:eq(error_body.message, "Insufficient balance")

	state.completion = nil
	state.deltas = {}
	state.message = nil
	state.provider_error = {
		status = 401,
		message = "invalid api key",
		type = "upstream_error",
		code = "1001",
	}
	-- Streaming errors are committed as HTTP 200 because SSE headers and the
	-- role chunk are sent before the upstream request starts.
	response = request(t, scheduler, port, "/v1/chat/completions", {
		model = "glm-4.7",
		messages = {{role = "user", content = "hi"}},
		stream = true,
	}, "proxy-secret-proxy-secret-proxy")
	t:eq(response.status, 200)
	t:eq(response.headers:get("Content-Type"), "text/event-stream")
	local events = parseSse(response.body)
	t:eq(events[1].choices[1].delta.role, "assistant")
	t:eq(events[2].error.code, "1001")
	t:assert(response.body:find("data: [DONE]", 1, true))
	server:stop()
end

---@param t testing.T
function test.rate_limits_requests(t)
	---@type glm.FakeClientState
	local state = {completion = {
		choices = {{message = {role = "assistant", content = "ok"}}},
	}}
	local server, scheduler = startServer(t, {
		max_requests_per_minute = 1,
		create_client = function() return fakeClient(state) end,
	})
	local _, port = server:getAddress()
	local token = "proxy-secret-proxy-secret-proxy"

	local response = request(t, scheduler, port, "/v1/chat/completions", {
		model = "glm-4.7",
		messages = {{role = "user", content = "hi"}},
	}, token)
	t:eq(response.status, 200)

	response = request(t, scheduler, port, "/v1/chat/completions", {
		model = "glm-4.7",
		messages = {{role = "user", content = "hi"}},
	}, token)
	t:eq(response.status, 429)
	t:eq(json.decode(response.body).error.code, "rate_limit_exceeded")
	server:stop()
end

return test
