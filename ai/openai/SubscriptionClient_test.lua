local json = require("web.json")
local OpenAiSubscriptionClient = require("ai.openai.SubscriptionClient")

local test = {}

---@param chunks string[]
---@return web.HttpStream
local function makeStream(chunks)
	return {
		res = {status = 200},
		sendBody = function(self, body)
			self.sent_body = body
			return #body
		end,
		receiveHeaders = function() return true end,
		receiveChunk = function() return table.remove(chunks, 1) end,
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

---@param open_stream aqua.openai.OpenStreamFunc
---@param max_response_size integer?
---@return aqua.openai.SubscriptionClient
local function makeClient(open_stream, max_response_size)
	return OpenAiSubscriptionClient({
		auth = {getAccess = function() return "access", "account" end} --[[@as aqua.openai.SubscriptionAuth]],
		model = "gpt-test",
		reasoning_effort = "medium",
		timeout = 45,
		max_response_size = max_response_size,
		open_stream = open_stream,
	})
end

---@param t testing.T
function test.encodes_responses_request_and_preserves_output_items(t)
	local stream = makeStream({
		[[data: {"type":"response.output_item.added","output_index":0,"item":{"type":"reasoning","summary":[]}}]] .. "\n\n",
		[[data: {"type":"response.output_item.done","output_index":0,"item":{"type":"reasoning","encrypted_content":"opaque","summary":[]}}]] .. "\n\n",
		[[data: {"type":"response.output_item.added","output_index":1,"item":{"type":"message","role":"assistant","content":[]}}]] .. "\n\n",
		[[data: {"type":"response.content_part.added","output_index":1,"content_index":0,"part":{"type":"output_text","text":"","annotations":[]}}]] .. "\n\n",
		[[data: {"type":"response.output_text.delta","output_index":1,"content_index":0,"delta":"Hi"}]] .. "\n\n",
		[[data: {"type":"response.completed","response":{"output":[],"usage":{"input_tokens":120,"output_tokens":30,"total_tokens":150,"input_tokens_details":{"cached_tokens":80},"output_tokens_details":{"reasoning_tokens":20}}}}]] .. "\n\n",
	})
	local called = {}
	local client = makeClient(function(url, options)
		called.url = url
		called.options = options
		return stream
	end)
	local deltas = {}
	local message = assert(client:completeStream({
		{role = "system", content = "instructions"},
		{role = "user", content = "hello"},
	}, {{
		type = "function",
		["function"] = {name = "inspect", description = "Inspect", parameters = {type = "object"}, strict = true},
	}}, function(delta) table.insert(deltas, delta) end))

	local body = json.decode(stream.sent_body)
	t:eq(called.url, OpenAiSubscriptionClient.responses_url)
	t:eq(called.options.headers.Authorization, "Bearer access")
	t:eq(called.options.headers["ChatGPT-Account-Id"], "account")
	t:eq(called.options.timeout, 45)
	t:eq(body.instructions, "instructions")
	t:eq(body.input[1].content[1].text, "hello")
	t:eq(body.tools[1].name, "inspect")
	t:eq(body.reasoning.effort, "medium")
	t:eq(table.concat(deltas), "Hi")
	t:eq(message.content, "Hi")
	t:eq(message.response_items[1].encrypted_content, "opaque")
	t:eq(message.usage.input_tokens, 120)
	t:eq(message.usage.output_tokens, 30)
	t:eq(message.usage.total_tokens, 150)
	t:eq(message.usage.input_tokens_details.cached_tokens, 80)
	t:eq(message.usage.output_tokens_details.reasoning_tokens, 20)

	local next_body = client:createBody({
		{role = "system", content = "instructions"},
		message,
	}, nil)
	t:eq(next_body.input[1], message.response_items[1])
	t:eq(next_body.input[2], message.response_items[2])
end

---@param t testing.T
function test.preserves_multimodal_responses_input_parts(t)
	local client = makeClient(function() error("not used") end)
	local content = {
		{type = "input_text", text = "inspect"},
		{type = "input_image", image_url = "data:image/png;base64,aGVsbG8=", detail = "high"},
		{type = "input_audio", input_audio = {data = "aGVsbG8=", format = "wav"}},
		{type = "input_file", file_data = "data:text/plain;base64,aGVsbG8=", filename = "hello.txt"},
	}
	local body = client:createBody({
		{role = "developer", content = "developer instructions"},
		{role = "system", content = "system instructions"},
		{role = "user", content = content},
	}, nil)
	t:eq(body.instructions, "developer instructions\n\nsystem instructions")
	t:eq(body.input[1].content, content)
end

---@param t testing.T
function test.converts_function_calls_and_tool_results(t)
	local stream = makeStream({
		[[data: {"type":"response.output_item.added","output_index":0,"item":{"type":"function_call","call_id":"call_1","name":"inspect","arguments":""}}]] .. "\n\n",
		[[data: {"type":"response.function_call_arguments.delta","output_index":0,"delta":"{\"path\":"}]] .. "\n\n",
		[[data: {"type":"response.function_call_arguments.done","output_index":0,"arguments":"{\"path\":\"game\"}"}]] .. "\n\n",
		[[data: {"type":"response.completed","response":{"output":[]}}]] .. "\n\n",
	})
	local client = makeClient(function() return stream end)
	local message = assert(client:completeStream({{role = "user", content = "inspect"}}))
	t:eq(message.content, "")
	t:eq(message.tool_calls[1].id, "call_1")
	t:eq(message.tool_calls[1]["function"].name, "inspect")

	local body = client:createBody({
		{role = "user", content = "inspect"},
		message,
		{role = "tool", tool_call_id = "call_1", content = "result"},
	}, nil)
	t:eq(body.input[2].type, "function_call")
	t:eq(body.input[3].type, "function_call_output")
	t:eq(body.input[3].output, "result")
end

---@param t testing.T
function test.reports_auth_and_stream_errors(t)
	local client = OpenAiSubscriptionClient({
		auth = {getAccess = function() return nil, nil, "login required" end} --[[@as aqua.openai.SubscriptionAuth]],
		model = "gpt-test",
		reasoning_effort = "medium",
		open_stream = function() error("not used") end,
	})
	local message, err = client:completeStream({})
	t:eq(message, nil)
	t:eq(err, "login required")

	local stream = makeStream({[[data: {"type":"error","message":"broken"}]] .. "\n\n"})
	client = makeClient(function() return stream end)
	message, err = client:completeStream({})
	t:eq(message, nil)
	t:eq(err, "broken")

	stream = makeStream({[[data: {"type":"response.output_text.delta","delta":"too large"}]] .. "\n\n"})
	client = makeClient(function() return stream end, 8)
	message, err = client:completeStream({})
	t:eq(message, nil)
	t:eq(err, "OpenAI subscription response is too large")
	t:assert(stream.closed)
end

return test
