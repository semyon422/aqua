local json = require("web.json")
local Client = require("ai.openai.Client")

local test = {}

---@param t testing.T
function test.complete_encodes_chat_request(t)
	local called = {}
	local client = Client({
		base_url = "http://localhost:28080/v1/",
		api_key = "secret",
		model = "local-model",
		max_tokens = 123,
		timeout = 45,
		request = function(url, body, options)
			called = {url = url, body = json.decode(body), options = options}
			return {status = 200, body = [[{"choices":[{"message":{"role":"assistant","content":"hello"}}]}]]}
		end,
	})

	local message = assert(client:complete({{role = "user", content = "hi"}}, {{
		type = "function",
		["function"] = {name = "example", parameters = {type = "object"}},
	}}))

	t:eq(message.content, "hello")
	t:eq(called.url, "http://localhost:28080/v1/chat/completions")
	t:eq(called.options.headers.Authorization, "Bearer secret")
	t:eq(called.options.headers["Content-Type"], "application/json")
	t:eq(called.options.timeout, 45)
	t:eq(called.body.model, "local-model")
	t:eq(called.body.max_tokens, 123)
	t:eq(called.body.parallel_tool_calls, false)
	t:eq(called.body.messages[1].content, "hi")
end

---@param t testing.T
function test.provider_and_shape_errors(t)
	local responses = {
		{status = 500, body = [[{"error":{"message":"broken"}}]]},
		{status = 200, body = "not json"},
		{status = 200, body = [[{"choices":[]}]]},
	}
	local client = Client({
		base_url = "http://localhost/v1",
		model = "model",
		request = function()
			return table.remove(responses, 1)
		end,
	})

	local _, err = client:complete({})
	t:eq(err, "provider returned HTTP 500: broken")
	_, err = client:complete({})
	t:assert(err:find("invalid provider JSON", 1, true))
	_, err = client:complete({})
	t:eq(err, "provider response is missing choices[1].message")
end

---@param chunks string[]
---@return web.HttpStream
local function makeStream(chunks)
	return {
		res = {status = 200},
		sendBody = function(self, body)
			self.sent_body = body
			return #body
		end,
		receiveHeaders = function()
			return true
		end,
		receiveAvailableChunk = function()
			return table.remove(chunks, 1)
		end,
		close = function(self)
			self.closed = true
			return true
		end,
		cancel = function(self, err)
			self.cancel_error = err
			return true
		end,
	}
end

---@param t testing.T
function test.streams_text_and_assembles_tool_calls(t)
	local streams = {
		makeStream({
			[[data: {"choices":[{"delta":{"content":"Hel"}}]}]], "\n\n",
			[[data: {"choices":[{"delta":{"content":"lo"}}]}]] .. "\n\n",
			"data: [DONE]\n\n",
		}),
		makeStream({
			[[data: {"choices":[{"delta":{"tool_calls":[{"index":0,"id":"call_1","type":"function","function":{"name":"lua_","arguments":"{\"co"}}]}}]}]] .. "\n\n",
			[[data: {"choices":[{"delta":{"tool_calls":[{"index":0,"function":{"name":"eval","arguments":"de\":\"1+1\"}"}}]}}]}]] .. "\n\n",
			"data: [DONE]\n\n",
		}),
	}
	local client = Client({
		base_url = "http://localhost/v1",
		model = "model",
		request = function() error("not used") end,
		open_stream = function()
			return table.remove(streams, 1)
		end,
	})
	local deltas = {}
	local message = assert(client:completeStream({}, nil, function(delta)
		table.insert(deltas, delta)
	end))
	t:eq(message.content, "Hello")
	t:eq(table.concat(deltas), "Hello")

	message = assert(client:completeStream({}, {}))
	t:eq(message.tool_calls[1].id, "call_1")
	t:eq(message.tool_calls[1]["function"].name, "lua_eval")
	t:eq(json.decode(message.tool_calls[1]["function"].arguments).code, "1+1")
end

---@param t testing.T
function test.cancels_active_stream(t)
	local client
	local stream = makeStream({})
	stream.receiveAvailableChunk = function()
		client:cancel()
		return nil, "canceled"
	end
	client = Client({
		base_url = "http://localhost/v1",
		model = "model",
		request = function() error("not used") end,
		open_stream = function() return stream end,
	})
	local message, err = client:completeStream({})
	t:eq(message, nil)
	t:eq(err, "canceled")
	t:eq(stream.cancel_error, "canceled")
	t:eq(json.decode(stream.sent_body).stream, true)
end

---@param t testing.T
function test.shared_transport_preserves_empty_messages_and_stream_metadata(t)
	local streams = {
		makeStream({"data: [DONE]\n\n"}),
		makeStream({
			[[data: {"choices":[{"delta":{"reasoning_content":"think"}}]}]] .. "\n\n",
			[[data: {"choices":[{"delta":{"content":"hi"},"finish_reason":"length"}]}]] .. "\n\n",
			[[data: {"choices":[],"usage":{"total_tokens":7}}]] .. "\n\n",
			"data: [DONE]\n\n",
		}),
	}
	local client = Client({base_url = "http://localhost/v1", model = "model",
		request = function() error("not used") end,
		open_stream = function() return table.remove(streams, 1) end})
	t:eq(assert(client:completeStream({})).content, "")
	local deltas = {}
	local message = assert(client:completeStream({}, nil, function(text) table.insert(deltas, text) end))
	t:tdeq(deltas, {"hi"})
	t:eq(message.reasoning_content, "think")
	t:eq(message.finish_reason, "length")
	t:eq(message.usage.total_tokens, 7)
end

---@param t testing.T
function test.shared_transport_terminal_guards_and_exception_cleanup(t)
	local delta = [[data: {"choices":[{"delta":{"content":"text"}}]}]] .. "\n\n"
	for _, terminal in ipairs({"done", "false", "cancel", "exception", "provider_error"}) do
		local payload = delta .. delta .. "data: [DONE]\n\n"
		if terminal == "done" then payload = delta .. "data: [DONE]\n\ndata: not JSON\n\n" end
		if terminal == "provider_error" then payload = [[data: {"error":{"message":"failed"}}]] .. "\n\n" .. delta end
		local stream = makeStream({payload})
		local client = Client({base_url = "http://localhost/v1", model = "model",
			request = function() error("not used") end, open_stream = function() return stream end})
		local callbacks = 0
		local message, err = client:completeStream({}, nil, function()
			callbacks = callbacks + 1
			if terminal == "false" then return false end
			if terminal == "cancel" then client:cancel() end
			if terminal == "exception" then error("SECRET-CALLBACK") end
		end)
		t:eq(callbacks, terminal == "provider_error" and 0 or 1)
		if terminal == "done" then
			t:eq(message.content, "text")
		else
			t:eq(message, nil)
			local errors = { ["false"] = "downstream response stream closed", cancel = "canceled",
				exception = "upstream stream failed", provider_error = "failed" }
			t:eq(err, errors[terminal])
		end
		t:eq(client.active_stream, nil)
		t:assert(stream.closed or stream.cancel_error)
	end
end

return test
