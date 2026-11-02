local json = require("web.json")
local ResponsesClient = require("ai.openai.ResponsesClient")

local test = {}

---@class openai.ResponsesClientFakeStream
---@field res {status: integer, headers: web.Headers?}
---@field response_body string?
---@field sent_body string?
---@field closed boolean?
---@field cancel_error string?

---@param chunks string[]
---@param status integer?
---@return openai.ResponsesClientFakeStream
local function makeStream(chunks, status)
	---@type openai.ResponsesClientFakeStream
	local stream = {
		res = {status = status or 200},
		sendBody = function(self, body)
			self.sent_body = body
			return #body
		end,
		receiveHeaders = function() return true end,
		setTimeout = function() return true end,
		receiveAvailableChunk = function() return table.remove(chunks, 1) end,
		receiveChunk = function(self)
			---@cast self openai.ResponsesClientFakeStream
			if self.response_body == nil then return nil, "closed" end
			local body = self.response_body
			self.response_body = nil
			return body
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
	return stream
end

---@param open_stream openai.OpenStreamFunc
---@param options table?
---@return openai.ResponsesClient
local function makeClient(open_stream, options)
	---@type openai.ResponsesClientOptions
	local client_options = {
		base_url = "http://127.0.0.1:28081/v1/",
		api_key = "proxy-token",
		model = "gpt-test",
		reasoning_effort = "medium",
		timeout = 45,
		open_stream = open_stream,
	}
	if options then
		-- LuaLS 3.19 does not propagate dynamic fixture keys through pairs().
		---@diagnostic disable-next-line: no-unknown
		for key, value in pairs(options) do
			---@cast key string
			client_options[key] = value
		end
	end
	return ResponsesClient(client_options)
end

---@param t testing.T
function test.sends_agent_messages_to_configured_endpoint(t)
	local stream = makeStream({
		[[data: {"type":"response.output_text.delta","output_index":0,"content_index":0,"delta":"Hi"}]] .. "\n\n",
		[[data: {"type":"response.completed","response":{"output":[],"usage":{"input_tokens":10,"output_tokens":2,"total_tokens":12}}}]] .. "\n\n",
	})
	local called = {}
	local client = makeClient(function(url, options)
		called.url = url
		called.options = options
		return stream
	end)
	local message = assert(client:completeStream(
		{
			{role = "system", content = "instructions"},
			{role = "user", content = "hello"},
		},
		{{
			type = "function",
			["function"] = {name = "inspect", description = "Inspect", parameters = {type = "object"}},
		}}
	))

	t:eq(called.url, "http://127.0.0.1:28081/v1/responses")
	t:eq(called.options.headers.Authorization, "Bearer proxy-token")
	t:eq(called.options.headers["x-client-request-id"] ~= nil, true)

	local body = json.decode(stream.sent_body)
	t:eq(body.model, "gpt-test")
	t:eq(body.store, false)
	t:eq(body.stream, true)
	t:eq(body.instructions, "instructions")
	t:eq(body.input[1].content[1].text, "hello")
	t:eq(body.tools[1].name, "inspect")
	t:eq(body.reasoning.effort, "medium")
	t:eq(message.content, "Hi")
	t:eq(message.finish_reason, "stop")
	t:eq(message.usage.total_tokens, 12)
	t:eq(message.response_items[1].type, "message")
	t:eq(message.response_items[1].content[1].text, "Hi")
end

---@param t testing.T
function test.native_request_is_forwarded_without_subscription_mutations(t)
	local stream = makeStream({
		[[data: {"type":"response.completed","response":{"id":"resp_1","status":"completed","output":[],"usage":{"input_tokens":5,"output_tokens":1,"total_tokens":6}}}]] .. "\n\n",
	})
	local client = makeClient(function() return stream end, {api_key = ""})
	local events = {}
	local response = assert(client:createResponse({
		model = "ignored-client-model",
		input = "hello",
		max_output_tokens = 4096,
		store = false,
		include = json.array({"message.output_text.logprobs"}),
	}, function(event)
		table.insert(events, event.type)
		return true
	end))

	local body = json.decode(stream.sent_body)
	t:eq(body.model, "gpt-test")
	t:eq(body.max_output_tokens, 4096)
	t:eq(body.include[1], "message.output_text.logprobs")
	t:eq(body.include[2], nil)
	t:eq(events[1], "response.completed")
	t:eq(response.id, "resp_1")
	t:eq(body.include[2], nil)
end

---@param t testing.T
function test.omits_authorization_without_api_key(t)
	local stream = makeStream({
		[[data: {"type":"response.output_item.done","output_index":0,"item":{"type":"message","role":"assistant","content":[{"type":"output_text","text":"Hi"}]}}]] .. "\n\n",
		[[data: {"type":"response.completed","response":{"output":[]}}]] .. "\n\n",
	})
	local client = makeClient(function() return stream end, {api_key = nil})
	assert(client:complete({{role = "user", content = "hello"}}))
end

---@param t testing.T
function test.reports_provider_errors_and_stream_failures(t)
	local stream = makeStream({})
	stream.res.status = 429
	stream.response_body = [[{"error":{"message":"rate limited","type":"rate_limit_error","code":"rate_limit_exceeded"}}]]
	local client = makeClient(function() return stream end)
	local message, err, provider_error = client:completeStream({})
	t:eq(message, nil)
	t:eq(err, "OpenAI Responses returned HTTP 429: rate limited")
	t:eq(provider_error.status, 429)
	t:eq(provider_error.code, "rate_limit_exceeded")

	local stream2 = makeStream({})
	stream2.res.status = 400
	stream2.response_body = [[{"detail":"bad input"}]]
	client = makeClient(function() return stream2 end)
	message, err = client:createResponse({input = "hello"})
	t:eq(message, nil)
	t:eq(err, "OpenAI Responses returned HTTP 400: bad input")

	local stream3 = makeStream({})
	local failed = false
	client = makeClient(function()
		failed = true
		error("connect refused")
	end)
	message, err = client:completeStream({})
	t:eq(message, nil)
	t:eq(err, "upstream stream failed")
	t:eq(failed, true)
end

---@param t testing.T
function test.complete_assembles_message_without_deltas(t)
	local stream = makeStream({
		[[data: {"type":"response.output_item.added","output_index":0,"item":{"type":"function_call","call_id":"call_1","name":"inspect","arguments":"{}"}}]] .. "\n\n",
		[[data: {"type":"response.completed","response":{"output":[{"type":"function_call","call_id":"call_1","name":"inspect","arguments":"{}"}]}}]] .. "\n\n",
	})
	local client = makeClient(function() return stream end)
	local message = assert(client:complete({{role = "user", content = "inspect"}}))
	t:eq(message.tool_calls[1].id, "call_1")
	t:eq(message.finish_reason, "tool_calls")
end

return test
