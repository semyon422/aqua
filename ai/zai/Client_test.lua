local ClientClass = require("ai.zai.Client")

local function Client(options)
	options.get_time = options.get_time or function() return 0 end
	return ClientClass(options)
end
local ChatCompletionsClient = require("ai.openai.ChatCompletionsClient")

local test = {}

---@param t testing.T
function test.keeps_required_key_and_provider_error_label(t)
	for _, api_key in ipairs({false, ""}) do
		local ok, err = pcall(Client, {base_url = "http://localhost/v1", api_key = api_key or nil,
			request = function() error("not used") end})
		t:eq(ok, false)
		t:assert(tostring(err):find("api_key is required", 1, true))
	end
	local client = Client({base_url = "http://localhost/v1", api_key = "secret",
		request = function() return {status = 429, body = "not JSON"} end})
	t:assert(ChatCompletionsClient * client)
	local completion, err, provider_error = client:complete({})
	t:eq(completion, nil)
	t:eq(err, "Z.ai provider returned HTTP 429")
	t:eq(provider_error.status, 429)
end

---@param t testing.T
function test.keeps_raw_completion_contract(t)
	local client = Client({base_url = "http://localhost/v1", api_key = "secret",
		request = function()
			return {status = 200, body = [[{"id":"completion","choices":[{"message":{"role":"assistant","content":"hello"},"finish_reason":"stop"}],"usage":{"total_tokens":8}}]]}
		end})
	local completion = assert(client:complete({model = "glm-4.7", messages = {}}))
	t:eq(completion.id, "completion")
	t:eq(completion.choices[1].message.content, "hello")
	t:eq(completion.usage.total_tokens, 8)
end

---@param t testing.T
function test.keeps_full_delta_callback_contract(t)
	local chunks = {
		[[data: {"choices":[{"delta":{"reasoning_content":"think"}}]}]] .. "\n\n",
		[[data: {"choices":[{"delta":{"content":"hello"},"finish_reason":"length"}]}]] .. "\n\n",
		[[data: {"choices":[],"usage":{"total_tokens":8}}]] .. "\n\n",
		"data: [DONE]\n\n",
	}
	local closed = false
	local client = Client({base_url = "http://localhost/v1", api_key = "secret",
		request = function() error("not used") end,
		open_stream = function()
			return {res = {status = 200}, sendBody = function() return true end,
				receiveHeaders = function() return true end,
				receiveAvailableChunk = function() return table.remove(chunks, 1) end,
				close = function() closed = true end}
		end})
	local deltas = {}
	local message = assert(client:completeStream({}, function(delta) table.insert(deltas, delta) end))
	t:eq(deltas[1].reasoning_content, "think")
	t:eq(deltas[2].content, "hello")
	t:eq(message.reasoning_content, "think")
	t:eq(message.content, "hello")
	t:eq(message.finish_reason, "length")
	t:eq(message.usage.total_tokens, 8)
	t:eq(closed, true)
	t:eq(client.active_stream, nil)
end

return test
