local json = require("web.json")
local Client = require("ai.zai.Client")

local test = {}

---@param t testing.T
function test.complete_encodes_request(t)
	local called = {}
	local client = Client({
		base_url = "https://api.z.ai/api/coding/paas/v4/",
		api_key = "secret",
		timeout = 45,
		request = function(url, body, options)
			called = {url = url, body = json.decode(body), options = options}
			return {status = 200, body = [[{"id":"1","model":"glm-4.7","choices":[{"message":{"role":"assistant","content":"hello"}}]}]]}
		end,
	})

	local completion = assert(client:complete({
		model = "glm-4.7",
		messages = {{role = "user", content = "hi"}},
		thinking = {type = "enabled"},
	}))

	t:eq(completion.choices[1].message.content, "hello")
	t:eq(called.url, "https://api.z.ai/api/coding/paas/v4/chat/completions")
	t:eq(called.options.headers.Authorization, "Bearer secret")
	t:eq(called.options.headers["Content-Type"], "application/json")
	t:eq(called.options.timeout, 45)
	t:eq(called.body.thinking.type, "enabled")
	t:eq(called.body.stream, false)
end

---@param t testing.T
function test.provider_and_shape_errors(t)
	local responses = {
		{status = 429, body = [[{"error":{"code":"1302","message":"rate limited"}}]]},
		{status = 200, body = "not json"},
		{status = 200, body = [[{"choices":[]}]]},
	}
	local client = Client({
		base_url = "https://api.z.ai/api/coding/paas/v4",
		api_key = "secret",
		request = function()
			return table.remove(responses, 1)
		end,
	})

	local completion, err, provider_error = client:complete({model = "glm-4.7", messages = {}})
	t:eq(completion, nil)
	t:eq(err, "rate limited")
	t:eq(provider_error.status, 429)
	t:eq(provider_error.code, "1302")

	completion, err = client:complete({model = "glm-4.7", messages = {}})
	t:eq(completion, nil)
	t:assert(err:find("invalid provider JSON", 1, true))

	completion, err = client:complete({model = "glm-4.7", messages = {}})
	t:eq(completion, nil)
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
		cancel = function(self, cancel_err)
			self.cancel_error = cancel_err
			return true
		end,
	}
end

---@param t testing.T
function test.streams_text_reasoning_and_tool_calls(t)
	local stream = makeStream({
		[[data: {"choices":[{"delta":{"role":"assistant","content":""}}]}]] .. "\n\n",
		[[data: {"choices":[{"delta":{"reasoning_content":"think "}}]}]] .. "\n\n",
		[[data: {"choices":[{"delta":{"reasoning_content":"hard"}}]}]] .. "\n\n",
		[[data: {"choices":[{"delta":{"content":"Hel"}}]}]] .. "\n\n",
		[[data: {"choices":[{"delta":{"content":"lo"}}]}]] .. "\n\n",
		[[data: {"choices":[{"delta":{},"finish_reason":"stop"}],"usage":{"prompt_tokens":3,"completion_tokens":5,"total_tokens":8}}]] .. "\n\n",
		"data: [DONE]\n\n",
	})
	local client = Client({
		base_url = "https://api.z.ai/api/coding/paas/v4",
		api_key = "secret",
		request = function() error("not used") end,
		open_stream = function()
			return stream
		end,
	})
	---@type table[]
	local deltas = {}
	local message = assert(client:completeStream({model = "glm-4.7", messages = {}}, function(delta)
		table.insert(deltas, delta)
	end))
	t:eq(message.content, "Hello")
	t:eq(message.reasoning_content, "think hard")
	t:eq(message.finish_reason, "stop")
	t:eq(message.usage.total_tokens, 8)
	t:eq(#deltas, 6)
	t:eq(deltas[2].reasoning_content, "think ")
	t:eq(json.decode(stream.sent_body).stream, true)
end

---@param t testing.T
function test.stream_assembles_fragmented_tool_calls(t)
	local stream = makeStream({
		[[data: {"choices":[{"delta":{"tool_calls":[{"index":0,"id":"call_1","type":"function","function":{"name":"lua_","arguments":"{\"co"}}]}}]}]] .. "\n\n",
		[[data: {"choices":[{"delta":{"tool_calls":[{"index":0,"function":{"name":"eval","arguments":"de\":\"1+1\"}"}}]}}]}]] .. "\n\n",
		[[data: {"choices":[{"delta":{},"finish_reason":"tool_calls"}]}]] .. "\n\n",
		"data: [DONE]\n\n",
	})
	local client = Client({
		base_url = "https://api.z.ai/api/coding/paas/v4",
		api_key = "secret",
		request = function() error("not used") end,
		open_stream = function()
			return stream
		end,
	})
	local message = assert(client:completeStream({model = "glm-4.7", messages = {}}))
	t:eq(message.content, "")
	t:eq(message.finish_reason, "tool_calls")
	t:eq(message.tool_calls[1].id, "call_1")
	t:eq(message.tool_calls[1]["function"].name, "lua_eval")
	t:eq(json.decode(message.tool_calls[1]["function"].arguments).code, "1+1")
end

---@param t testing.T
function test.stream_requires_done_sentinel(t)
	local stream = makeStream({
		[[data: {"choices":[{"delta":{"content":"hi"}}]}]] .. "\n\n",
	})
	local client = Client({
		base_url = "https://api.z.ai/api/coding/paas/v4",
		api_key = "secret",
		request = function() error("not used") end,
		open_stream = function()
			return stream
		end,
	})
	local message, err = client:completeStream({model = "glm-4.7", messages = {}})
	t:eq(message, nil)
	t:eq(err, "stream closed before [DONE]")
end

---@param t testing.T
function test.stream_aborts_when_downstream_closes(t)
	local stream = makeStream({
		[[data: {"choices":[{"delta":{"content":"first"}}]}]] .. "\n\n",
		[[data: {"choices":[{"delta":{"content":"second"}}]}]] .. "\n\n",
	})
	local client = Client({
		base_url = "https://api.z.ai/api/coding/paas/v4",
		api_key = "secret",
		request = function() error("not used") end,
		open_stream = function()
			return stream
		end,
	})
	local message, err = client:completeStream({model = "glm-4.7", messages = {}}, function()
		return false
	end)
	t:eq(message, nil)
	t:eq(err, "downstream response stream closed")
	t:eq(stream.cancel_error, "downstream response stream closed")
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
		base_url = "https://api.z.ai/api/coding/paas/v4",
		api_key = "secret",
		request = function() error("not used") end,
		open_stream = function() return stream end,
	})
	local message, err = client:completeStream({model = "glm-4.7", messages = {}})
	t:eq(message, nil)
	t:eq(err, "canceled")
	t:eq(stream.cancel_error, "canceled")
end

---@param t testing.T
function test.non_json_http_errors_preserve_status(t)
	for _, status in ipairs({401, 403, 429, 503}) do
		local stream = makeStream({"<html>upstream error</html>"})
		stream.res.status = status
		local client = Client({base_url = "http://localhost/v1", api_key = "secret",
			request = function() return {status = status, body = "not JSON"} end,
			open_stream = function() return stream end})
		local _, _, err = client:complete({})
		t:eq(err.status, status)
		local _, _, stream_err = client:completeStream({})
		t:eq(stream_err.status, status)
		t:eq(stream.closed, true)
		t:eq(client.active_stream, nil)
	end
end

---@param t testing.T
function test.coalesced_events_stop_after_cancel_error_or_done(t)
	local delta = [[data: {"choices":[{"delta":{"content":"text"}}]}]] .. "\n\n"
	for _, terminal in ipairs({"cancel", "error", "done"}) do
		local payload = delta .. delta
		if terminal == "error" then payload = [[data: {"error":{"message":"failed","type":"rate_limit_error"}}]] .. "\n\n" .. delta end
		if terminal == "done" then payload = delta .. "data: [DONE]\n\n" .. delta end
		local stream = makeStream({payload})
		local client = Client({base_url = "http://localhost/v1", api_key = "secret",
			request = function() error("not used") end, open_stream = function() return stream end})
		local callbacks = 0
		local message, err, provider_error = client:completeStream({}, function()
			callbacks = callbacks + 1
			if terminal == "cancel" then return false end
		end)
		t:eq(callbacks, terminal == "error" and 0 or 1)
		if terminal == "done" then t:eq(message.content, "text")
		elseif terminal == "error" then t:eq(provider_error.type, "rate_limit_error")
		else t:eq(err, "downstream response stream closed") end
		t:eq(client.active_stream, nil)
	end
end

---@param t testing.T
function test.stream_exceptions_close_resources(t)
	for _, failure in ipairs({"sendBody", "receiveHeaders", "receiveAvailableChunk", "callback"}) do
		local stream = makeStream({[[data: {"choices":[{"delta":{"content":"text"}}]}]] .. "\n\n"})
		if failure ~= "callback" then stream[failure] = function() error("SECRET-EXCEPTION") end end
		local client = Client({base_url = "http://localhost/v1", api_key = "secret",
			request = function() error("not used") end, open_stream = function() return stream end})
		local message, err = client:completeStream({}, function() error("SECRET-CALLBACK") end)
		t:eq(message, nil)
		t:eq(err, "upstream stream failed")
		t:eq(stream.closed, true)
		t:eq(client.active_stream, nil)
	end
end

---@param t testing.T
function test.stream_timeout_is_a_total_deadline(t)
	local delta = [[data: {"choices":[{"delta":{"content":"text"}}]}]] .. "\n\n"
	local stream = makeStream({delta, delta, delta})
	local timeouts = {}
	stream.setTimeout = function(_, timeout) table.insert(timeouts, timeout) end
	local now = 0
	local client = Client({base_url = "http://localhost/v1", api_key = "secret", timeout = 1,
		get_time = function() return now end,
		request = function() error("not used") end, open_stream = function() return stream end})
	local callbacks = 0
	local message, err = client:completeStream({}, function()
		callbacks = callbacks + 1
		now = now + 0.5
	end)
	t:eq(message, nil)
	t:eq(err, "upstream request timeout exceeded")
	t:eq(callbacks, 2)
	t:eq(timeouts[#timeouts], 0.5)
	t:eq(stream.cancel_error, err)
	t:eq(client.active_stream, nil)
end

---@param t testing.T
function test.streaming_error_body_is_bounded_by_size_and_deadline(t)
	for _, limit in ipairs({"size", "deadline"}) do
		local now, reads = 0, 0
		local stream = makeStream({})
		stream.res.status = 429
		stream.setTimeout = function() end
		stream.receiveAvailableChunk = function()
			reads = reads + 1
			if limit == "size" then return string.rep("x", Client.max_error_body_size + 1) end
			now = now + 0.5
			return "x"
		end
		local client = Client({base_url = "http://localhost/v1", api_key = "secret", timeout = 1,
			get_time = function() return now end,
			request = function() error("not used") end, open_stream = function() return stream end})
		local message, _, err = client:completeStream({})
		t:eq(message, nil)
		t:eq(err.status, 429)
		t:eq(reads, limit == "size" and 1 or 2)
		t:eq(stream.closed, true)
		t:eq(client.active_stream, nil)
	end
end

return test
