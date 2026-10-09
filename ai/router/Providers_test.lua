local json = require("web.json")
local ZaiProvider = require("ai.router.ZaiProvider")
local CompatProvider = require("ai.router.CompatProvider")
local OpenAIProvider = require("ai.router.OpenAIProvider")
local Provider = require("ai.router.Provider")

local test = {}

-- Request fixtures are built through a JSON roundtrip so nested tables carry
-- the array/object markers that decoded client bodies have in production.
---@param text string
---@return table
local function requestBody(text)
	return assert(json.decode(text))
end

local zai_config = {
	base_url = "https://api.z.ai/api/coding/paas/v4",
	api_key = "test-key-test-key-test-key",
	models = {"glm-5.3", "glm-5.3-flash"},
	model_redirects = {["glm-5.3-flash"] = "glm-5.3"},
	thinking = "disabled",
	tool_stream = false,
}

-- Non-streaming zai request fake; captures the encoded upstream body.
---@param response_body string?
---@param status integer?
---@return zai.RequestFunc request
---@return fun(): table? get_captured
local function fakeZaiRequest(response_body, status)
	---@type any
	local captured
	local request = function(_, body, _options)
		captured = body and json.decode(body) or nil
		return {status = status or 200, body = response_body or "{}"}
	end
	return request, function() return captured end
end

---@param t testing.T
function test.zai_provider_normalizes_and_canonicalizes(t)
	local response_body = json.encode({
		id = "1",
		model = "glm-5.3",
		choices = {{index = 0, message = {
			role = "assistant",
			content = "hello",
			reasoning_content = "thought",
		}, finish_reason = "stop"}},
		usage = {prompt_tokens = 3, completion_tokens = 2, total_tokens = 5},
	})
	local request, captured = fakeZaiRequest(response_body)
	local provider = ZaiProvider({config = zai_config, request = request, timeout = 5})

	local message, err, provider_error = provider:complete(requestBody([[
		{"model": "glm-5.3-flash", "messages": [{"role": "user", "content": "hi"}]}
	]]), "glm-5.3")
	t:eq(err, nil)
	t:eq(provider_error, nil)
	t:eq(message.content, "hello")
	t:eq(message.reasoning_content, "thought")
	t:eq(message.finish_reason, "stop")
	t:eq(message.usage.input_tokens, 3)
	t:eq(message.usage.output_tokens, 2)
	t:eq(message.usage.cached_input_tokens, 0)

	local upstream = captured()
	t:eq(upstream.model, "glm-5.3")
	t:eq(upstream.thinking.type, "disabled")
	t:eq(upstream.messages[1].content, "hi")
end

---@param t testing.T
function test.zai_provider_rejects_unsupported_fields_locally(t)
	local request = function() error("must not be called") end
	local provider = ZaiProvider({config = zai_config, request = request, timeout = 5})

	local message, err, provider_error = provider:complete(requestBody([[
		{"model": "glm-5.3", "messages": [{"role": "user", "content": "hi"}], "seed": 1}
	]]), "glm-5.3")
	t:eq(message, nil)
	t:eq(err, nil)
	t:eq(provider_error.status, 400)
	t:eq(provider_error.type, "invalid_request_error")
	t:eq(provider_error.code, "unsupported_parameter")
end

-- Builds an SSE fake stream serving the given data lines.
---@param data_lines string[]
---@return zai.OpenStreamFunc
local function fakeOpenStream(data_lines)
	---@type string[]
	local events = {}
	for i, line in ipairs(data_lines) do
		events[i] = "data: " .. line .. "\n\n"
	end
	return function()
		local remaining = table.concat(events)
		return {
			res = {status = 200},
			sendBody = function(_, body) return #body end,
			receiveHeaders = function() return true end,
			setTimeout = function() end,
			receiveAvailableChunk = function()
				local chunk = remaining:match("^[^\n]*\n\n")
				if not chunk then return nil, "closed" end
				remaining = remaining:sub(#chunk + 1)
				if remaining == "" then remaining = nil end
				return chunk
			end,
			close = function() return true end,
			cancel = function() return true end,
		}
	end
end

---@param t testing.T
function test.zai_provider_relays_stream_deltas(t)
	local open_stream = fakeOpenStream({
		json.encode({id = "1", model = "glm-5.3", choices = {{index = 0, delta = {content = "he"}}}}),
		json.encode({id = "1", model = "glm-5.3", choices = {{index = 0, delta = {content = "llo"}}}}),
		json.encode({id = "1", model = "glm-5.3", choices = {{index = 0, delta = {}, finish_reason = "stop"}},
			usage = {prompt_tokens = 1, completion_tokens = 2, total_tokens = 3}}),
		"[DONE]",
	})
	local provider = ZaiProvider({
		config = zai_config,
		request = function() error("streaming uses open_stream") end,
		open_stream = open_stream,
		timeout = 5,
	})

	---@type table[]
	local relayed = {}
	local message = provider:completeStream(requestBody([[
		{"model": "glm-5.3", "messages": [{"role": "user", "content": "hi"}], "stream": true}
	]]), "glm-5.3", function(delta)
		table.insert(relayed, delta)
	end)
	t:tdeq(relayed, {{content = "he"}, {content = "llo"}, {}})
	t:eq(message.content, "hello")
	t:eq(message.usage.input_tokens, 1)
	t:eq(message.usage.output_tokens, 2)
end

---@param t testing.T
function test.compat_provider_forwards_body_verbatim(t)
	---@type any
	local captured
	local request = function(_, body, _options)
		captured = json.decode(body)
		return {status = 200, body = json.encode({
			id = "1",
			model = "llama",
			choices = {{index = 0, message = {role = "assistant", content = "hi"}, finish_reason = "stop"}},
			usage = {prompt_tokens = 4, completion_tokens = 6, total_tokens = 10,
				prompt_tokens_details = {cached_tokens = 2}},
		})}
	end
	local provider = CompatProvider({
		config = {base_url = "http://127.0.0.1:8080/v1", models = {"llama-70b"}},
		request = request,
		timeout = 5,
	})

	local message = provider:complete(requestBody([[
		{"model": "llama-70b", "messages": [{"role": "user", "content": "hi"}],
		 "temperature": 0.7, "top_k": 40}
	]]), "llama-70b")
	t:eq(message.content, "hi")
	t:eq(message.usage.input_tokens, 4)
	t:eq(message.usage.output_tokens, 6)
	t:eq(message.usage.cached_input_tokens, 2)

	local upstream = captured
	t:eq(upstream.model, "llama-70b")
	t:eq(upstream.temperature, 0.7)
	t:eq(upstream.top_k, 40)
end

---@param t testing.T
function test.openai_provider_validates_and_streams(t)
	---@type string[]
	local upstream_bodies
	local open_stream = fakeOpenStream({
		json.encode({type = "response.output_text.delta", delta = "he"}),
		json.encode({type = "response.output_text.delta", delta = "llo"}),
		json.encode({type = "response.completed", response = {id = "r1", usage = {
			input_tokens = 7, output_tokens = 3, total_tokens = 10,
			input_tokens_details = {cached_tokens = 4},
		}}}),
	})
	local provider = OpenAIProvider({
		config = {auth_path = "unused"},
		auth = {getAccess = function() return "access", "account" end},
		request = function() error("usage only") end,
		open_stream = function(url, options)
			local stream = open_stream(url, options)
			local sendBody = stream.sendBody
			stream.sendBody = function(self, body)
				table.insert(upstream_bodies, body)
				return sendBody(self, body)
			end
			return stream
		end,
		timeout = 5,
	})

	upstream_bodies = {}
	---@type table[]
	local relayed = {}
	local message = provider:complete(requestBody([[
		{"model": "gpt-6-luna", "messages": [{"role": "user", "content": "hi"}], "stream": true}
	]]), "gpt-6-luna", function(delta)
		table.insert(relayed, delta)
	end)
	t:tdeq(relayed, {{content = "he"}, {content = "llo"}})
	t:eq(message.content, "hello")
	t:eq(message.usage.input_tokens, 7)
	t:eq(message.usage.output_tokens, 3)
	t:eq(message.usage.cached_input_tokens, 4)
	t:eq(#upstream_bodies, 1)

	-- provider-local validation errors surface as 400 without upstream work
	local result, err, provider_error = provider:complete(requestBody([[
		{"model": "gpt-6-luna", "messages": [{"role": "user", "content": "hi"}], "temperature": 0.3}
	]]), "gpt-6-luna")
	t:eq(result, nil)
	t:eq(err, nil)
	t:eq(provider_error.status, 400)
	t:eq(provider_error.code, "unsupported_parameter")
	t:eq(#upstream_bodies, 1)
end

---@param t testing.T
function test.provider_canonical_usage_dialects(t)
	t:eq(Provider.canonicalUsage(nil), nil)
	t:eq(Provider.canonicalUsage(json.object()), nil)
	t:tdeq(Provider.canonicalUsage({
		input_tokens = 5, output_tokens = 6, total_tokens = 11,
		input_tokens_details = {cached_tokens = 2},
	}), {input_tokens = 5, output_tokens = 6, cached_input_tokens = 2})
	t:tdeq(Provider.canonicalUsage({
		prompt_tokens = 5, completion_tokens = 6, total_tokens = 11,
		prompt_tokens_details = {cached_tokens = 1},
	}), {input_tokens = 5, output_tokens = 6, cached_input_tokens = 1})
end

return test
