local coext = require("coext")
---@type {gettime: fun(): number}
local socket = require("socket")
local json = require("web.json")
local digest = require("digest")
local CosocketScheduler = require("web.luasocket.CosocketScheduler")
local http_util = require("web.http.util")
local Server = require("ai.router.Server")
local UsageMonitor = require("ai.router.UsageMonitor")
local UsageRepo = require("ai.router.UsageRepo")
local UsersRepo = require("ai.router.UsersRepo")
local ChannelsRepo = require("ai.router.ChannelsRepo")
local ModelsRepo = require("ai.router.ModelsRepo")
local RouterDatabase = require("ai.router.storage.RouterDatabase")
local LjsqliteDatabase = require("rdb.db.LjsqliteDatabase")
local Headers = require("web.http.Headers")
local HttpServer = require("web.http.Server")
local HttpStream = require("web.http.HttpStream")
local CompatProvider = require("ai.router.CompatProvider")

local test = {}

local TOKEN = "router-secret-router-secret-router"

---@class test.FakeProvider
---@field complete (fun(self: test.FakeProvider, body: table, upstream_model: string): ai.router.CanonicalMessage?, string?, table?)?
---@field completeStream (fun(self: test.FakeProvider, body: table, upstream_model: string, on_delta: fun(delta: table): boolean?): ai.router.CanonicalMessage?, string?, table?)?
---@field fetchUsage (fun(self: test.FakeProvider): table?, string?, table?)?
---@field complete_count integer
---@field stream_count integer
---@field bodies table[]
---@field models string[]
---@field session_id string?
---@field createResponse fun(self: test.FakeProvider, body: table, upstream_model: string, session_id: string?, on_event: (fun(event: table): boolean?)?): table?, string?, table?

-- A fake provider returning a canned canonical message or failures.
---@param opts {message: table?, response: table?, events: table[]?, err: string?, provider_error: table?, deltas: table[]?, fetch_usage: fun(): table?, string?, table?}?
---@return test.FakeProvider
local function fakeProvider(opts)
	opts = opts or {}
	---@type test.FakeProvider
	local provider = {
		complete_count = 0,
		stream_count = 0,
		---@type table[]
		bodies = {},
		---@type string[]
		models = {},
	}
	function provider:complete(body, upstream_model)
		self.complete_count = self.complete_count + 1
		table.insert(self.bodies, body)
		table.insert(self.models, upstream_model)
		if opts.message then return opts.message end
		return nil, opts.err, opts.provider_error
	end
	function provider:completeStream(body, upstream_model, on_delta)
		self.stream_count = self.stream_count + 1
		table.insert(self.bodies, body)
		table.insert(self.models, upstream_model)
		for _, delta in ipairs(opts.deltas or {}) do
			if on_delta(delta) == false then
				return nil, "downstream response stream closed"
			end
		end
		if opts.message then return opts.message end
		return nil, opts.err, opts.provider_error
	end
	function provider:createResponse(body, upstream_model, session_id, on_event)
		self.complete_count = self.complete_count + 1
		table.insert(self.bodies, body)
		table.insert(self.models, upstream_model)
		self.session_id = session_id
		if on_event then
			for _, event in ipairs(opts.events or {}) do
				if on_event(event) == false then return nil, "downstream response stream closed" end
			end
		end
		return opts.response, opts.err, opts.provider_error
	end
	if opts.fetch_usage then
		function provider:fetchUsage()
			return opts.fetch_usage()
		end
	end
	return provider
end

-- Full router stack on an in-memory database with fake providers.
---@class test.Stack
---@field storage ai.router.RouterDatabase
---@field server ai.router.Server
---@field scheduler web.CosocketScheduler
---@field users ai.router.UsersRepo
---@field channels ai.router.ChannelsRepo
---@field models ai.router.ModelsRepo
---@field monitor ai.router.UsageMonitor
---@field usage_repo ai.router.UsageRepo
---@field providers_by_name {[string]: test.FakeProvider}
---@field user ai.router.UserRow

---@param opts {providers: {[string]: test.FakeProvider}}?
---@return test.Stack
local function startStack(opts)
	local storage = RouterDatabase(LjsqliteDatabase())
	storage.path = ":memory:"
	storage:open()
	local users = UsersRepo(storage.models)
	local channels = ChannelsRepo(storage.models)
	local models = ModelsRepo(storage.models)
	local usage_repo = UsageRepo(storage.models)
	local monitor = UsageMonitor({
		usage_repo = usage_repo,
		logger = function() end,
	})
	---@type {[string]: test.FakeProvider}
	local providers_by_name = {}
	if opts and opts.providers then
		providers_by_name = opts.providers
	end
	local scheduler = CosocketScheduler()
	local server = Server({
		scheduler = scheduler,
		users_repo = users,
		usage_repo = usage_repo,
		monitor = monitor,
		logger = function() end,
		provider_factory = function(channel)
			return providers_by_name[channel.name]
		end,
	})
	local user = users:create("alice", 1000)
	-- deterministic key for tests: overwrite the generated hash
	storage.models.router_users:update(
		{key_hash = digest.hash("sha256", TOKEN, true), key_hint = TOKEN:sub(-4)},
		{id = user.id}
	)
	users:setGrants(user.id, {"zai-1/glm-5.3", "openai-1/gpt-6-luna", "lite"})
	channels:create("zai-1", "zai", {
		base_url = "https://api.z.ai/api/coding/paas/v4",
		api_key = "key",
		models = {"glm-5.3"},
	}, {}, 1000)
	channels:create("openai-1", "openai_compat", {
		base_url = "http://localhost:28080/v1",
		models = {"gpt-6-luna", "glm-5.3"},
	}, {}, 1000)
	models:create("lite", "zai-1/glm-5.3", nil, 1000)
	server:reload(channels:list(), models:list())
	local stack = {
		storage = storage,
		server = server,
		scheduler = scheduler,
		users = users,
		channels = channels,
		models = models,
		monitor = monitor,
		usage_repo = usage_repo,
		providers_by_name = providers_by_name,
		user = user,
	}
	assert(server:start("127.0.0.1", 0))
	return stack
end

---@param t testing.T
---@param stack test.Stack
---@param thread thread
local function pump(t, stack, thread)
	local deadline = socket.gettime() + 2
	while coroutine.status(thread) ~= "dead" do
		local ok, err = stack.scheduler:update(0.01)
		if not ok and err then error(err) end
		t:assert(socket.gettime() < deadline)
	end
end

---@param t testing.T
---@param stack test.Stack
---@param path string
---@param body table?
---@param token string?
---@param extra_headers {[string]: string}?
---@return {status: integer, body: string}
local function request(t, stack, path, body, token, extra_headers)
	---@type {status: integer, body: string}?
	local response
	---@type string?
	local request_err
	local thread = coext.detach(coroutine.create(function()
		local headers = {}
		if token then headers.Authorization = "Bearer " .. token end
		for name, value in pairs(extra_headers or {}) do headers[name] = value end
		local _, port = stack.server:getAddress()
		local result, err = http_util.request(
			("http://127.0.0.1:%d%s"):format(assert(port), path),
			body and json.encode(body) or nil,
			{
				method = body and "POST" or "GET",
				headers = headers,
				scheduler = stack.scheduler,
				timeout = 1,
			}
		)
		response = result and {status = result.status, body = result.body} or nil
		request_err = err
	end))
	coroutine.resume(thread)
	pump(t, stack, thread)
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

local ok_message = {
	content = "hello",
	reasoning_content = nil,
	tool_calls = nil,
	finish_reason = "stop",
	usage = {input_tokens = 10, output_tokens = 5, cached_input_tokens = 2},
}

---@param t testing.T
function test.routes_non_streaming_and_records_usage(t)
	local zai = fakeProvider({message = ok_message})
	local stack = startStack({providers = {["zai-1"] = zai, ["openai-1"] = fakeProvider({message = ok_message})}})
	local response = request(t, stack, "/v1/chat/completions", {
		model = "zai-1/glm-5.3",
		messages = json.array({{role = "user", content = "hi"}}),
	}, TOKEN)
	t:eq(response.status, 200)
	local completion = json.decode(response.body)
	t:eq(completion.model, "zai-1/glm-5.3")
	t:eq(completion.choices[1].message.content, "hello")
	t:eq(completion.choices[1].finish_reason, "stop")
	t:eq(completion.usage.prompt_tokens, 10)
	t:eq(completion.usage.prompt_tokens_details.cached_tokens, 2)
	t:eq(zai.models[1], "glm-5.3")

	---@type {rows: any[]}
	local history = stack.usage_repo:history(os.time())
	t:eq(#history.rows, 1)
	local row = history.rows[1]
	t:eq(row.user, "alice")
	t:eq(row.model, "zai-1/glm-5.3")
	t:eq(row.upstream_model, "glm-5.3")
	t:eq(row.channel, "zai-1")
	t:eq(row.input_tokens, 10)
	t:eq(row.cached_input_tokens, 2)
	t:eq(row.estimated_requests, 0)
	stack.server:stop()
	stack.storage:close()
end

---@param t testing.T
function test.transport_error_and_429_never_switch_channel(t)
	local failing = fakeProvider({err = "upstream request failed"})
	local quota = fakeProvider({provider_error = {
		status = 429, message = "rate limited", type = "rate_limit_error", code = "rate_limit_exceeded",
	}})
	local serving = fakeProvider({message = ok_message})
	local stack = startStack({providers = {["zai-1"] = serving, ["openai-1"] = failing}})
	local response = request(t, stack, "/v1/chat/completions", {
		model = "openai-1/gpt-6-luna",
		messages = json.array({{role = "user", content = "hi"}}),
	}, TOKEN)
	t:eq(response.status, 502)
	t:eq(json.decode(response.body).error.code, "upstream_error")

	-- The alias pins both model and channel.
	stack.providers_by_name["zai-1"] = failing
	stack.providers_by_name["openai-1"] = serving
	stack.server:reload(stack.channels:list(), stack.models:list())
	response = request(t, stack, "/v1/chat/completions", {
		model = "lite",
		messages = json.array({{role = "user", content = "hi"}}),
	}, TOKEN)
	t:eq(response.status, 502)
	t:eq(failing.complete_count, 2)
	t:eq(serving.complete_count, 0)

	-- Quota errors return to the caller and refresh display-only monitoring.
	stack.providers_by_name["zai-1"] = quota
	stack.server:reload(stack.channels:list(), stack.models:list())
	local refreshed = false
	local original_refresh = stack.monitor.refresh
	---@param monitor ai.router.UsageMonitor
	stack.monitor.refresh = function(monitor, id)
		refreshed = true
		return original_refresh(monitor, id)
	end
	response = request(t, stack, "/v1/chat/completions", {
		model = "lite",
		messages = json.array({{role = "user", content = "hi"}}),
	}, TOKEN)
	t:eq(response.status, 429)
	t:eq(serving.complete_count, 0)
	t:assert(refreshed)
	stack.server:stop()
	stack.storage:close()
end

---@param t testing.T
function test.local_400_does_not_fail_over(t)
	local strict = fakeProvider({provider_error = {
		status = 400, message = "seed is not supported", type = "invalid_request_error", code = "unsupported_parameter",
	}})
	local other = fakeProvider({message = ok_message})
	local stack = startStack({providers = {["zai-1"] = strict, ["openai-1"] = other}})
	local response = request(t, stack, "/v1/chat/completions", {
		model = "lite",
		messages = json.array({{role = "user", content = "hi"}}),
	}, TOKEN)
	t:eq(response.status, 400)
	t:eq(json.decode(response.body).error.code, "unsupported_parameter")
	t:eq(strict.complete_count, 1)
	t:eq(other.complete_count, 0)
	stack.server:stop()
	stack.storage:close()
end

---@param t testing.T
function test.quota_snapshots_do_not_change_selected_channel(t)
	local depleted = fakeProvider({message = ok_message})
	local serving = fakeProvider({message = ok_message})
	local stack = startStack({providers = {["zai-1"] = depleted, ["openai-1"] = serving}})
	-- fresh upstream snapshot: zai-1 is 95% full
	stack.monitor:setChannels(stack.server.router.state.channels, {})
	stack.monitor:saveWindow(stack.server.router.state.channels[1], "five_hour",
		{used_percent = 95}, "upstream", os.time())
	local response = request(t, stack, "/v1/chat/completions", {
		model = "lite",
		messages = json.array({{role = "user", content = "hi"}}),
	}, TOKEN)
	t:eq(response.status, 200)
	t:eq(depleted.complete_count, 1)
	t:eq(serving.complete_count, 0)
	stack.server:stop()
	stack.storage:close()
end

---@param t testing.T
function test.streams_deltas_with_delayed_commit(t)
	local zai = fakeProvider({
		deltas = {{content = "he"}, {content = "llo"}},
		message = {content = "hello", usage = {input_tokens = 3, output_tokens = 2, cached_input_tokens = 0}},
	})
	local stack = startStack({providers = {["zai-1"] = zai, ["openai-1"] = fakeProvider({message = ok_message})}})
	local response = request(t, stack, "/v1/chat/completions", {
		model = "zai-1/glm-5.3",
		messages = json.array({{role = "user", content = "hi"}}),
		stream = true,
		stream_options = {include_usage = true},
	}, TOKEN)
	t:eq(response.status, 200)
	local events = parseSse(response.body)
	t:eq(events[1].choices[1].delta.role, "assistant")
	t:eq(events[2].choices[1].delta.content, "he")
	t:eq(events[3].choices[1].delta.content, "llo")
	t:eq(events[#events - 1].choices[1].finish_reason, "stop")
	t:eq(events[#events].choices, nil or events[#events].choices)
	t:eq(#events[#events].choices, 0)
	t:eq(events[#events].usage.prompt_tokens, 3)
	t:assert(response.body:find("data: [DONE]", 1, true))

	-- a provider that fails before any delta yields a plain HTTP error
	local failing = fakeProvider({err = "no upstream"})
	stack.providers_by_name["zai-1"] = failing
	stack.providers_by_name["openai-1"] = failing
	stack.server:reload(stack.channels:list(), stack.models:list())
	response = request(t, stack, "/v1/chat/completions", {
		model = "zai-1/glm-5.3",
		messages = json.array({{role = "user", content = "hi"}}),
		stream = true,
	}, TOKEN)
	t:eq(response.status, 502)
	stack.server:stop()
	stack.storage:close()
end

---@param t testing.T
function test.grants_and_models_endpoint(t)
	local stack = startStack({providers = {["zai-1"] = fakeProvider({message = ok_message})}})
	local response = request(t, stack, "/v1/models", nil, TOKEN)
	t:eq(response.status, 200)
	---@type any
	local decoded = json.decode(response.body)
	t:eq(decoded.object, "list")
	---@type string[]
	local ids = {}
	---@type any[]
	local data = decoded.data
	for i, model in ipairs(data) do
		ids[i] = model.id
	end
	-- user grants intersect the public catalog; getGrants sorts by name
	t:tdeq(ids, {"lite", "openai-1/gpt-6-luna", "zai-1/glm-5.3"})

	-- ungranted public model
	response = request(t, stack, "/v1/chat/completions", {
		model = "zai-1/glm-5.3",
		messages = json.array({{role = "user", content = "hi"}}),
	}, TOKEN)
	t:eq(response.status, 200)
	stack.users:setGrants(stack.user.id, {"lite"})
	stack.server:reload(stack.channels:list(), stack.models:list())
	response = request(t, stack, "/v1/chat/completions", {
		model = "zai-1/glm-5.3",
		messages = json.array({{role = "user", content = "hi"}}),
	}, TOKEN)
	t:eq(response.status, 404)
	t:eq(json.decode(response.body).error.code, "model_not_found")

	response = request(t, stack, "/v1/chat/completions", {
		model = "missing",
		messages = json.array({{role = "user", content = "hi"}}),
	}, TOKEN)
	t:eq(response.status, 404)

	response = request(t, stack, "/v1/models", nil, "wrong-token-wrong-token-wrong")
	t:eq(response.status, 401)
	stack.server:stop()
	stack.storage:close()
end

---@param t testing.T
function test.streaming_errors_before_and_after_output_never_switch(t)
	local first = fakeProvider({deltas = {{role = "assistant", content = ""}, {}}, err = "timeout"})
	local second = fakeProvider({deltas = {{content = "hello"}}, message = ok_message})
	local stack = startStack({providers = {["zai-1"] = first, ["openai-1"] = second}})
	local body = {model = "lite", messages = {{role = "user", content = "hi"}}, stream = true}
	local response = request(t, stack, "/v1/chat/completions", body, TOKEN)
	t:eq(response.status, 502)
	t:eq(second.stream_count, 0)
	local row = stack.usage_repo:history(os.time()).rows[1]
	t:eq(row.channel, "zai-1")
	t:eq(row.upstream_model, "glm-5.3")
	first = fakeProvider({deltas = {{content = "partial"}}, err = "timeout"})
	stack.providers_by_name["zai-1"] = first
	stack.server:reload(stack.channels:list(), stack.models:list())
	response = request(t, stack, "/v1/chat/completions", body, TOKEN)
	t:eq(response.status, 200)
	t:eq(second.stream_count, 0)
	local events = parseSse(response.body)
	t:eq(events[2].choices[1].delta.content, "partial")
	t:eq(events[3].error.code, "upstream_error")
	t:eq(#events, 3)
	t:assert(response.body:find("data: [DONE]", 1, true))
	local rows = stack.usage_repo:history(os.time()).rows
	local errors = 0
	for _, item in ipairs(rows) do errors = errors + item.errors end
	t:eq(errors, 2)
	t:eq(next(stack.server.active_requests), nil)
	stack.server:stop()
	stack.storage:close()
end

---@param t testing.T
function test.exceptions_release_slots_and_do_not_leak_details(t)
	local broken = fakeProvider()
	broken.complete = function() error("SECRET-PROVIDER") end
	local fallback = fakeProvider({message = ok_message})
	local stack = startStack({providers = {["zai-1"] = broken, ["openai-1"] = fallback}})
	local body = {model = "lite", messages = {{role = "user", content = "hi"}}}
	t:eq(request(t, stack, "/v1/chat/completions", body, TOKEN).status, 502)
	local complete = stack.server.complete
	stack.server.complete = function() error("SECRET-HANDLER") end
	local response = request(t, stack, "/v1/chat/completions", body, TOKEN)
	t:eq(response.status, 500)
	t:eq(response.body:find("SECRET", 1, true), nil)
	t:eq(next(stack.server.active_requests), nil)
	stack.server.complete = complete
	t:eq(request(t, stack, "/v1/chat/completions", body, TOKEN).status, 502)
	broken.completeStream = function(_, _, _, callback)
		callback({content = "partial"})
		error("SECRET-STREAM")
	end
	body.stream = true
	response = request(t, stack, "/v1/chat/completions", body, TOKEN)
	t:eq(response.status, 200)
	t:eq(parseSse(response.body)[3].error.code, "upstream_error")
	t:eq(fallback.stream_count, 0)
	t:eq(response.body:find("SECRET", 1, true), nil)
	t:eq(next(stack.server.active_requests), nil)
	stack.server:stop()
	stack.storage:close()
end

---@param t testing.T
function test.authentication_errors_do_not_cool_down_and_are_counted(t)
	local bad = fakeProvider({provider_error = {status = 401, message = "unauthorized", type = "authentication_error", code = "unauthorized"}})
	local good = fakeProvider({message = ok_message})
	local stack = startStack({providers = {["zai-1"] = bad, ["openai-1"] = good}})
	local now = 1000
	stack.server.get_time = function() return now end
	local body = {model = "lite", messages = {}}
	t:eq(request(t, stack, "/v1/chat/completions", body, TOKEN).status, 401)
	t:eq(request(t, stack, "/v1/chat/completions", body, TOKEN).status, 401)
	t:eq(bad.complete_count, 2)
	now = 1600
	t:eq(request(t, stack, "/v1/chat/completions", body, TOKEN).status, 401)
	t:eq(bad.complete_count, 3)
	stack.providers_by_name["zai-1"] = fakeProvider({provider_error = {
		status = 400, message = "bad request", type = "invalid_request_error", code = "invalid_request"}})
	stack.server:reload(stack.channels:list(), stack.models:list())
	for _, stream in ipairs({false, true}) do
		body.stream = stream
		t:eq(request(t, stack, "/v1/chat/completions", body, TOKEN).status, 400)
	end
	t:eq(good.complete_count, 0)
	local errors = 0
	for _, row in ipairs(stack.usage_repo:history(os.time()).rows) do errors = errors + row.errors end
	t:eq(errors, 5)
	stack.server:stop()
	stack.storage:close()
end

---@class test.RouterResponse: web.Response
---@field writes integer
---@field fail_after integer
local RouterResponse = {}

function RouterResponse:set_chunked_encoding() end
function RouterResponse:send_headers()
	self.headers_sent = true
	return 1
end
---@param data string
---@return integer?
function RouterResponse:send(data)
	self.writes = self.writes + 1
	if self.writes > self.fail_after then return nil end
	return #data
end

---@param t testing.T
function test.downstream_write_failures_never_fail_over(t)
	local first = fakeProvider({deltas = {{content = "first"}, {content = "second"}}, message = ok_message})
	local fallback = fakeProvider({message = ok_message})
	local stack = startStack({providers = {["zai-1"] = first, ["openai-1"] = fallback}})
	-- Fail the role write, a content write, or the terminal write.
	for _, fail_after in ipairs({0, 1, 3}) do
		local res = setmetatable({headers = Headers(), writes = 0, fail_after = fail_after}, {__index = RouterResponse})
		local status, result = stack.server:complete(res, {model = "lite", stream = true}, stack.user)
		t:eq(status, 499)
		t:eq(result.downstream_closed, true)
		t:eq(result.channel, "zai-1")
		t:eq(fallback.stream_count, 0)
	end
	stack.server:stop()
	stack.storage:close()
end

---@param t testing.T
function test.user_limit_overrides_and_key_rotation_share_counters(t)
	local stack = startStack({providers = {["zai-1"] = fakeProvider({message = ok_message})}})
	stack.users:update(stack.user.id, {max_rpm = 1, max_concurrency = 1}, os.time())
	local body = {model = "zai-1/glm-5.3", messages = {}}
	t:eq(request(t, stack, "/v1/chat/completions", body, TOKEN).status, 200)
	local key = stack.users:regenerateKey(stack.user.id, os.time())
	t:eq(request(t, stack, "/v1/chat/completions", body, key).status, 429)
	stack.server.request_windows = {}
	t:assert(stack.server:acquireRequest(tostring(stack.user.id), 1))
	t:eq(request(t, stack, "/v1/chat/completions", body, key).status, 429)
	stack.server:releaseRequest(tostring(stack.user.id))
	stack.server:stop()
	stack.storage:close()
end

---@param t testing.T
function test.real_upstream_auth_failure_and_stream_timeout(t)
	local fallback = fakeProvider({message = ok_message, deltas = {{content = "hello"}}})
	local stack = startStack({providers = {["openai-1"] = fallback}})
	local upstream = HttpServer(stack.scheduler, function(req, res)
		assert(req:receive("*a"))
		if req.uri == "/auth/chat/completions" then
			res.status = 401
			res:set_length(6)
			res:send("denied")
		else
			res.headers:set("Content-Type", "text/event-stream")
			res:set_chunked_encoding()
			res:send([[data: {"choices":[{"delta":{"role":"assistant","content":""}}]}]] .. "\n\n")
			stack.scheduler:sleep(0.15)
			res:send("data: [DONE]\n\n")
			res:send("")
		end
	end, {client_timeout = 1})
	assert(upstream:start("127.0.0.1", 0))
	local _, port = upstream:getAddress()
	local closed = 0
	for _, mode in ipairs({"auth", "stall"}) do
		stack.providers_by_name["zai-1"] = CompatProvider({
			config = {base_url = ("http://127.0.0.1:%d/%s"):format(port, mode), models = {"glm-5.3"}}, timeout = 0.05,
			request = function(url, body, options)
				options.scheduler = stack.scheduler
				return http_util.request(url, body, options)
			end,
			open_stream = function(url, options)
				options.scheduler = stack.scheduler
				options.on_close = function() closed = closed + 1 end
				local stream = HttpStream(options)
				local ok, err = stream:connect(url)
				if not ok then stream:close() return nil, err end
				return stream
			end,
		})
		stack.server:reload(stack.channels:list(), stack.models:list())
		local response = request(t, stack, "/v1/chat/completions", {model = "lite", messages = {}, stream = true}, TOKEN)
		t:eq(response.status, mode == "auth" and 401 or 502)
		t:eq(next(stack.server.active_requests), nil)
	end
	t:eq(closed, 2)
	t:eq(fallback.stream_count, 0)
	upstream:stop()
	stack.server:stop()
	stack.storage:close()
end

---@param t testing.T
function test.pre_output_failures_call_only_selected_channel_once(t)
	for _, stream in ipairs({false, true}) do
		for _, code in ipairs({429, 500, 503}) do
			local first = fakeProvider({provider_error = {status = code, message = "failed", type = "upstream_error", code = "failed"}})
			local second = fakeProvider({err = "timeout"})
			local stack = startStack({providers = {["zai-1"] = first, ["openai-1"] = second}})
			local refreshed = 0
			stack.monitor.refresh = function(_, id) t:eq(id, 1) refreshed = refreshed + 1 end
			local response = request(t, stack, "/v1/chat/completions", {model = "lite", stream = stream, messages = {}}, TOKEN)
			t:eq(response.status, code)
			t:eq(first.complete_count + first.stream_count, 1)
			t:eq(second.complete_count + second.stream_count, 0)
			t:eq(refreshed, code == 429 and 1 or 0)
			t:eq(next(stack.server.active_requests), nil)
			stack.server:stop()
			stack.storage:close()
		end
	end
end

---@param t testing.T
function test.real_downstream_disconnect_closes_upstream_and_releases_slot(t)
	local fallback = fakeProvider({message = ok_message})
	local stack = startStack({providers = {["openai-1"] = fallback}})
	local upstream = HttpServer(stack.scheduler, function(req, res)
		assert(req:receive("*a"))
		res.headers:set("Content-Type", "text/event-stream")
		res:set_chunked_encoding()
		for _ = 1, 20 do
			if not res:send([[data: {"choices":[{"delta":{"content":"text"}}]}]] .. "\n\n") then return end
			stack.scheduler:sleep(0.01)
		end
		res:send("data: [DONE]\n\n")
		res:send("")
	end, {client_timeout = 1})
	assert(upstream:start("127.0.0.1", 0))
	local _, upstream_port = upstream:getAddress()
	local closed = 0
	stack.providers_by_name["zai-1"] = CompatProvider({
		config = {base_url = ("http://127.0.0.1:%d"):format(upstream_port), models = {"glm-5.3"}}, timeout = 1,
		request = function() error("not used") end,
		open_stream = function(url, options)
			options.scheduler = stack.scheduler
			options.on_close = function() closed = closed + 1 end
			local stream = HttpStream(options)
			assert(stream:connect(url))
			return stream
		end,
	})
	stack.server:reload(stack.channels:list(), stack.models:list())
	local log
	stack.server.logger = function(line) log = line end
	local failure
	local thread = coext.detach(coroutine.create(function()
		local ok, err = pcall(function()
			local _, port = stack.server:getAddress()
			local client = HttpStream({scheduler = stack.scheduler, timeout = 1, method = "POST",
				headers = {Authorization = "Bearer " .. TOKEN}})
			assert(client:connect(("http://127.0.0.1:%d/v1/chat/completions"):format(port)))
			assert(client:sendBody(json.encode({model = "lite", messages = {}, stream = true})))
			assert(client:receiveHeaders())
			client:cancel("test disconnect")
			while next(stack.server.active_requests) do stack.scheduler:sleep(0.01) end
		end)
		if not ok then failure = err end
	end))
	coroutine.resume(thread)
	pump(t, stack, thread)
	if failure then error(failure) end
	t:eq(closed, 1)
	t:eq(fallback.stream_count, 0)
	t:assert(log:find("status=499", 1, true))
	local rows = stack.server.request_logs_repo:list({}, os.time())
	t:eq(rows[1].status, 499)
	t:eq(rows[1].channel, "zai-1")
	t:eq(rows[1].error_code, "client_disconnected")
	t:eq(rows[1].output_tps, nil)
	upstream:stop()
	stack.server:stop()
	stack.storage:close()
end

---@param t testing.T
function test.alias_never_falls_back_to_another_model(t)
	local failing = fakeProvider({err = "unavailable"})
	local other = fakeProvider({message = ok_message})
	local stack = startStack({providers = {["zai-1"] = failing, ["openai-1"] = other}})
	stack.channels:update(2, {kind = "openai", config = {models = {"gpt-6-luna"}}}, 1001)
	stack.server:reload(stack.channels:list(), stack.models:list())
	stack.users:setGrants(stack.user.id, {"lite"})
	stack.providers_by_name["zai-1"] = fakeProvider({message = ok_message})
	stack.server:reload(stack.channels:list(), stack.models:list())
	local response = request(t, stack, "/v1/chat/completions", {model = "lite", messages = {}}, TOKEN)
	t:eq(response.status, 200)
	t:eq(json.decode(response.body).model, "lite")
	stack.providers_by_name["zai-1"] = failing
	stack.server:reload(stack.channels:list(), stack.models:list())
	for _, stream in ipairs({false, true}) do
		local response = request(t, stack, "/v1/chat/completions", {model = "lite", messages = {}, stream = stream}, TOKEN)
		t:eq(response.status, 502)
	end
	t:eq(other.complete_count, 0)
	t:eq(other.stream_count, 0)
	stack.server:stop()
	stack.storage:close()
end

---@param stack test.Stack
---@param name string
---@param provider test.FakeProvider
---@return ai.router.ChannelRow
local function addNative(stack, name, provider)
	stack.providers_by_name[name] = provider
	local row = stack.channels:create(name, "openai", {
		models = {"gpt-6-luna", "glm-5.3"},
		model_redirects = {["glm-5.3"] = "native-model"},
	}, {}, 1000)
	local grants = stack.users:getGrants(stack.user.id)
	table.insert(grants, name .. "/gpt-6-luna")
	table.insert(grants, name .. "/glm-5.3")
	stack.users:setGrants(stack.user.id, grants)
	local alias = stack.models:findByName("lite")
	if alias.target == "zai-1/glm-5.3" then
		stack.models:update(alias.id, {target = name .. "/glm-5.3"}, 1001)
	end
	stack.server:reload(stack.channels:list(), stack.models:list())
	return row
end

local native_result = {
	id = "resp_1", object = "response", status = "completed", model = "native-model",
	output = {{type = "reasoning", encrypted_content = "opaque"},
		{type = "function_call", id = "fc_1", call_id = "call_1", name = "inspect", arguments = "{}"}},
	usage = {input_tokens = 10, output_tokens = 5, input_tokens_details = {cached_tokens = 4}},
}

---@param t testing.T
function test.native_responses_preserve_items_aliases_affinity_and_usage(t)
	local wrong = fakeProvider({message = ok_message})
	local stack = startStack({providers = {["zai-1"] = wrong, ["openai-1"] = wrong}})
	local native = fakeProvider({response = native_result})
	addNative(stack, "native-1", native)
	local body = {model = "lite", input = {{type = "reasoning", encrypted_content = "previous"},
		{type = "function_call_output", call_id = "previous-call", output = "result"}},
		tools = {{type = "function", name = "inspect", parameters = {type = "object"}}},
		prompt_cache_key = "thread"}
	local response = request(t, stack, "/v1/responses", body, TOKEN)
	t:eq(response.status, 200)
	local decoded = json.decode(response.body)
	t:eq(decoded.id, "resp_1")
	t:eq(decoded.model, "lite")
	t:eq(decoded.output[1].encrypted_content, "opaque")
	t:eq(decoded.output[2].call_id, "call_1")
	t:eq(decoded.usage.input_tokens_details.cached_tokens, 4)
	t:eq(wrong.complete_count, 0)
	t:eq(native.models[1], "native-model")
	t:eq(native.bodies[1].input[1].encrypted_content, "previous")
	t:eq(native.session_id, digest.hash("sha256", "thread", true))
	t:eq(request(t, stack, "/v1/responses", body, TOKEN,
		{['x-session-affinity'] = "explicit-thread", ['x-client-request-id'] = "request-1"}).status, 200)
	t:eq(native.session_id, "explicit-thread")
	local row = stack.usage_repo:history(os.time()).rows[1]
	t:eq(row.requests, 2)
	t:eq(row.channel, "native-1")
	t:eq(row.model, "lite")
	t:eq(row.upstream_model, "native-model")
	t:eq(row.input_tokens, 20)
	t:eq(row.cached_input_tokens, 8)
	t:eq(row.estimated_requests, 0)
	stack.server:stop()
	stack.storage:close()
end

---@param t testing.T
function test.native_endpoint_validation_grants_and_protocol_isolation(t)
	local stack = startStack()
	t:eq(request(t, stack, "/v1/responses", {model = "lite", input = "hi"}, TOKEN).status, 400)
	local native = fakeProvider({response = native_result})
	addNative(stack, "native-1", native)
	stack.channels:update(2, {config = {base_url = "http://localhost/v1", models = {"glm-5.3"}}}, 1001)
	stack.server:reload(stack.channels:list(), stack.models:list())
	local response = request(t, stack, "/v1/chat/completions", {model = "native-1/gpt-6-luna", messages = {}}, TOKEN)
	t:eq(response.status, 400)
	t:eq(json.decode(response.body).error.code, "unsupported_protocol")
	for _, fields in ipairs({{store = true}, {previous_response_id = "resp_old"},
		{background = true}, {input = json.object()}, {parallel_tool_calls = "yes"}}) do
		fields.model = "lite"
		if fields.input == nil then fields.input = "hi" end
		t:eq(request(t, stack, "/v1/responses", fields, TOKEN).status, 400)
	end
	t:eq(request(t, stack, "/v1/responses", {model = "lite", input = "hi"}, TOKEN,
		{['x-session-affinity'] = "bad header"}).status, 400)
	stack.users:setGrants(stack.user.id, {"gpt-6-luna"})
	t:eq(request(t, stack, "/v1/responses", {model = "lite", input = "hi"}, TOKEN).status, 404)
	t:eq(request(t, stack, "/v1/responses", {model = "gpt-6-luna", input = "hi"}, "wrong-key").status, 401)
	t:eq(native.complete_count, 0)
	t:eq(next(stack.server.active_requests), nil)
	stack.server:stop()
	stack.storage:close()
end

---@param t testing.T
function test.native_stream_errors_never_switch_channel(t)
	local stack = startStack()
	local first = fakeProvider({provider_error = {status = 429, type = "rate_limit_error", code = "rate_limit_exceeded"}})
	local second = fakeProvider({response = native_result, events = {
		{type = "response.created", response = {id = "resp_1", model = "native-model", status = "in_progress"}},
		{type = "response.completed", response = native_result},
	}})
	addNative(stack, "native-1", first)
	addNative(stack, "native-2", second)
	local refreshed
	stack.monitor.refresh = function(_, id) refreshed = id end
	local body = {model = "lite", input = "hi", stream = true}
	local response = request(t, stack, "/v1/responses", body, TOKEN)
	t:eq(response.status, 429)
	t:eq(refreshed, 3)
	t:eq(first.complete_count, 1)
	t:eq(second.complete_count, 0)
	body.model = "native-2/glm-5.3"
	response = request(t, stack, "/v1/responses", body, TOKEN)
	t:eq(response.status, 200)
	t:eq(second.complete_count, 1)
	t:assert(response.body:find("event: response.created", 1, true))
	t:assert(response.body:find("event: response.completed", 1, true))
	t:eq(response.body:find("[DONE]", 1, true), nil)
	t:eq(parseSse(response.body)[1].response.model, "native-2/glm-5.3")
	t:eq(native_result.model, "native-model")
	stack.providers_by_name["native-1"] = fakeProvider({err = "timeout", events = {
		{type = "response.created", response = {id = "resp_failed", model = "native-model"}},
	}})
	stack.server:reload(stack.channels:list(), stack.models:list())
	body.model = "lite"
	response = request(t, stack, "/v1/responses", body, TOKEN)
	t:eq(response.status, 200)
	t:eq(second.complete_count, 1)
	t:eq(parseSse(response.body)[2].type, "error")
	t:eq(response.body:find("[DONE]", 1, true), nil)
	local errors = 0
	for _, row in ipairs(stack.usage_repo:history(os.time()).rows) do errors = errors + row.errors end
	t:eq(errors, 2)
	stack.server:stop()
	stack.storage:close()
end

---@param t testing.T
function test.native_auth_errors_quota_snapshots_and_downstream_failures(t)
	local stack = startStack()
	local first = fakeProvider({provider_error = {status = 401, type = "authentication_error", code = "unauthorized"}})
	local second = fakeProvider({response = native_result, events = {{type = "response.completed", response = native_result}}})
	addNative(stack, "native-1", first)
	addNative(stack, "native-2", second)
	local body = {model = "lite", input = "hi"}
	t:eq(request(t, stack, "/v1/responses", body, TOKEN).status, 401)
	t:eq(request(t, stack, "/v1/responses", body, TOKEN).status, 401)
	t:eq(first.complete_count, 2)
	t:eq(second.complete_count, 0)
	stack.providers_by_name["native-1"] = second
	stack.server:reload(stack.channels:list(), stack.models:list())
	for _, channel in ipairs(stack.server.router.state.channels) do
		if channel.id == 3 then
			stack.monitor:saveWindow(channel, "five_hour", {used_percent = 95}, "upstream", os.time())
		end
	end
	t:eq(request(t, stack, "/v1/responses", body, TOKEN).status, 200)
	t:eq(first.complete_count, 2)
	for _, fail_after in ipairs({0, 1}) do
		local res = setmetatable({headers = Headers(), writes = 0, fail_after = fail_after}, {__index = RouterResponse})
		body.stream = true
		local status, result = stack.server:complete(res, body, stack.user, "responses")
		t:eq(status, 499)
		t:eq(result.downstream_closed, true)
	end
	t:eq(first.complete_count, 2)
	stack.server:stop()
	stack.storage:close()
end

---@param t testing.T
function test.native_failed_and_incomplete_results_remain_native(t)
	local stack = startStack()
	local native = fakeProvider()
	addNative(stack, "native-1", native)
	local refreshed = 0
	stack.monitor.refresh = function() refreshed = refreshed + 1 end
	for _, status in ipairs({"failed", "incomplete"}) do
		local result = {id = "resp_" .. status, object = "response", status = status,
			output = {}, usage = {input_tokens = 2, output_tokens = 1},
			error = status == "failed" and {code = "rate_limit_exceeded", message = "quota"} or nil,
			incomplete_details = status == "incomplete" and {reason = "max_output_tokens"} or nil}
		native = fakeProvider({response = result, events = {{type = "response." .. status, response = result}}})
		stack.providers_by_name["native-1"] = native
		stack.server:reload(stack.channels:list(), stack.models:list())
		for _, streaming in ipairs({false, true}) do
			local response = request(t, stack, "/v1/responses", {model = "lite", input = "hi", stream = streaming}, TOKEN)
			t:eq(response.status, 200)
			local decoded = streaming and parseSse(response.body)[1].response or json.decode(response.body)
			t:eq(decoded.status, status)
			t:eq(decoded.model, "lite")
		end
	end
	t:eq(refreshed, 2)
	local row = stack.usage_repo:history(os.time()).rows[1]
	t:eq(row.requests, 4)
	t:eq(row.errors, 2)
	t:eq(row.input_tokens, 8)
	stack.server:stop()
	stack.storage:close()
end

---@param t testing.T
function test.protocols_share_user_limits_and_native_exceptions_are_sanitized(t)
	local stack = startStack({providers = {["zai-1"] = fakeProvider({message = ok_message})}})
	local native = fakeProvider({response = native_result})
	addNative(stack, "native-1", native)
	stack.users:update(stack.user.id, {max_rpm = 1}, os.time())
	t:eq(request(t, stack, "/v1/chat/completions", {model = "zai-1/glm-5.3", messages = {}}, TOKEN).status, 200)
	t:eq(request(t, stack, "/v1/responses", {model = "lite", input = "hi"}, TOKEN).status, 429)
	t:eq(native.complete_count, 0)
	stack.users:update(stack.user.id, {max_rpm = 100}, os.time())
	native.createResponse = function() error("SECRET-NATIVE") end
	local response = request(t, stack, "/v1/responses", {model = "lite", input = "hi"}, TOKEN)
	t:eq(response.status, 502)
	t:eq(response.body:find("SECRET", 1, true), nil)
	t:eq(next(stack.server.active_requests), nil)
	stack.server:stop()
	stack.storage:close()
end

---@param t testing.T
function test.qualified_grants_do_not_authorize_other_channels_or_bare_names(t)
	local first = fakeProvider({message = ok_message})
	local second = fakeProvider({message = ok_message})
	local stack = startStack({providers = {["zai-1"] = first, ["openai-1"] = second}})
	for _, model in ipairs({"glm-5.3", "openai-1/glm-5.3"}) do
		t:eq(request(t, stack, "/v1/chat/completions", {model = model, messages = {}}, TOKEN).status, 404)
	end
	t:eq(first.complete_count, 0)
	t:eq(second.complete_count, 0)
	stack.users:setGrants(stack.user.id, {"openai-1/glm-5.3"})
	local response = request(t, stack, "/v1/chat/completions", {model = "openai-1/glm-5.3", messages = {}}, TOKEN)
	t:eq(response.status, 200)
	t:eq(json.decode(response.body).model, "openai-1/glm-5.3")
	t:eq(second.models[1], "glm-5.3")
	t:eq(second.bodies[1].model, "glm-5.3")
	t:eq(first.complete_count, 0)
	stack.channels:update(2, {enabled = false}, os.time())
	stack.server:reload(stack.channels:list(), stack.models:list())
	t:eq(request(t, stack, "/v1/chat/completions", {model = "openai-1/glm-5.3", messages = {}}, TOKEN).status, 404)
	t:eq(first.complete_count, 0)
	stack.server:stop()
	stack.storage:close()
end

---@param t testing.T
function test.request_logs_capture_both_protocols_and_local_rejections(t)
	local provider = fakeProvider({message = ok_message, deltas = {{content = "hello"}}})
	local stack = startStack({providers = {["zai-1"] = provider}})
	local body = {model = "lite", messages = {{role = "user", content = "PRIVATE-PROMPT"}}}
	for _, stream in ipairs({false, true}) do
		body.stream = stream
		t:eq(request(t, stack, "/v1/chat/completions", body, TOKEN).status, 200)
	end
	local native = fakeProvider({response = native_result, events = {{type = "response.completed", response = native_result}}})
	addNative(stack, "native-log", native)
	t:eq(request(t, stack, "/v1/responses", {model = "lite", input = "PRIVATE-PROMPT", stream = true}, TOKEN).status, 200)
	local rows = stack.server.request_logs_repo:list({}, os.time())
	t:eq(#rows, 3)
	t:eq(rows[1].protocol, "responses")
	t:eq(rows[1].channel, "native-log")
	t:eq(rows[1].upstream_model, "native-model")
	t:eq(rows[1].cached_input_tokens, 4)
	t:eq(rows[1].estimated, false)
	t:eq(rows[2].stream, true)
	t:eq(rows[3].stream, false)
	t:eq(rows[3].ttft_ms, nil)
	t:eq(rows[3].output_tps, nil)
	t:eq(rows[3].model, "lite")
	t:eq(rows[3].user, "alice")
	t:assert(rows[3].duration_ms >= 0)
	t:eq(json.encode(rows):find("PRIVATE-PROMPT", 1, true), nil)
	t:eq(json.encode(rows):find(TOKEN, 1, true), nil)
	t:eq(request(t, stack, "/v1/responses", {model = "lite", input = "hi", store = true}, TOKEN).status, 400)
	stack.users:update(stack.user.id, {max_rpm = 1}, os.time())
	t:eq(request(t, stack, "/v1/responses", {model = "lite", input = "hi"}, TOKEN).status, 429)
	rows = stack.server.request_logs_repo:list({}, os.time())
	t:eq(#rows, 5)
	t:eq(rows[1].status, 429)
	t:eq(rows[1].error_code, "rate_limit")
	t:eq(rows[1].model, "")
	t:eq(rows[2].status, 400)
	t:eq(rows[2].error_code, "invalid_request")
	t:eq(rows[2].estimated, true)
	request(t, stack, "/v1/models", nil, TOKEN)
	request(t, stack, "/v1/responses", {model = "lite", input = "hi"}, "wrong-key")
	t:eq(#stack.server.request_logs_repo:list({}, os.time()), 5)
	stack.server:stop()
	stack.storage:close()
end

---@param t testing.T
function test.request_logs_preserve_upstream_and_streaming_outcomes(t)
	local bad = fakeProvider({provider_error = {status = 429, message = "PRIVATE-ERROR", type = "rate_limit_error", code = "rate_limit_exceeded"}})
	local stack = startStack({providers = {["zai-1"] = bad}})
	stack.monitor.refresh = function() end
	t:eq(request(t, stack, "/v1/chat/completions", {model = "lite", messages = {}}, TOKEN).status, 429)
	local partial = fakeProvider({err = "PRIVATE-ERROR", deltas = {{content = "partial"}}})
	stack.providers_by_name["zai-1"] = partial
	stack.server:reload(stack.channels:list(), stack.models:list())
	t:eq(request(t, stack, "/v1/chat/completions", {model = "lite", messages = {}, stream = true}, TOKEN).status, 200)
	local rows = stack.server.request_logs_repo:list({}, os.time())
	t:eq(rows[1].status, 502)
	t:eq(rows[1].channel, "zai-1")
	t:eq(rows[2].status, 429)
	t:eq(rows[2].channel, "zai-1")
	t:eq(rows[2].error_code, "rate_limit")
	t:eq(json.encode(rows):find("PRIVATE-ERROR", 1, true), nil)
	local log_message
	stack.server.logger = function(line) log_message = line end
	stack.server.request_logs_repo.record = function() error("PRIVATE-SQL-ERROR") end
	stack.providers_by_name["zai-1"] = fakeProvider({message = ok_message})
	stack.server:reload(stack.channels:list(), stack.models:list())
	t:eq(request(t, stack, "/v1/chat/completions", {model = "lite", messages = {}}, TOKEN).status, 200)
	t:eq(log_message:find("PRIVATE", 1, true), nil)
	t:eq(next(stack.server.active_requests), nil)
	stack.server:stop()
	stack.storage:close()
end

---@param t testing.T
function test.stream_metrics_measure_output_not_role_or_lifecycle_events(t)
	local now = 100
	local provider = fakeProvider()
	function provider:completeStream(_, _, on_delta)
		now = 101
		on_delta({role = "assistant", content = ""})
		now = 102
		on_delta({reasoning_content = "thinking"})
		now = 104
		on_delta({content = "hello"})
		now = 106
		return ok_message
	end
	local stack = startStack({providers = {["zai-1"] = provider}})
	stack.server.get_time = function() return now end
	t:eq(request(t, stack, "/v1/chat/completions", {model = "lite", messages = {}, stream = true}, TOKEN).status, 200)
	local rows = stack.server.request_logs_repo:list({}, os.time())
	t:eq(rows[1].ttft_ms, 2000)
	t:eq(rows[1].generation_ms, 4000)
	t:eq(rows[1].output_tps, 1.25)
	t:eq(rows[1].error_code, nil)
	local native = fakeProvider()
	function native:createResponse(_, _, _, on_event)
		now = 111
		on_event({type = "response.created", response = {id = "resp_1"}})
		now = 112
		on_event({type = "response.output_text.delta", delta = ""})
		now = 113
		on_event({type = "response.function_call_arguments.delta", delta = "{}"})
		now = 115
		on_event({type = "response.completed", response = native_result})
		return native_result
	end
	addNative(stack, "timed-native", native)
	now = 110
	t:eq(request(t, stack, "/v1/responses", {model = "lite", input = "hi", stream = true}, TOKEN).status, 200)
	rows = stack.server.request_logs_repo:list({}, os.time())
	t:eq(rows[1].ttft_ms, 3000)
	t:eq(rows[1].generation_ms, 2000)
	t:eq(rows[1].output_tps, 2.5)
	stack.server:stop()
	stack.storage:close()
end

---@param t testing.T
function test.request_error_codes_cover_timeout_auth_local_and_failed_responses(t)
	local stack = startStack({providers = {["zai-1"] = fakeProvider({err = "PRIVATE timeout"})}})
	t:eq(request(t, stack, "/v1/chat/completions", {model = "lite", messages = {}}, TOKEN).status, 502)
	t:eq(stack.server.request_logs_repo:list({}, os.time())[1].error_code, "timeout")
	stack.providers_by_name["zai-1"] = fakeProvider({provider_error = {status = 401, message = "PRIVATE", code = "PRIVATE"}})
	stack.server:reload(stack.channels:list(), stack.models:list())
	t:eq(request(t, stack, "/v1/chat/completions", {model = "lite", messages = {}}, TOKEN).status, 401)
	t:eq(stack.server.request_logs_repo:list({}, os.time())[1].error_code, "auth")
	t:eq(request(t, stack, "/v1/chat/completions", {model = "missing", messages = {}}, TOKEN).status, 404)
	t:eq(stack.server.request_logs_repo:list({}, os.time())[1].error_code, "model_not_found")
	t:eq(request(t, stack, "/v1/responses", {model = "lite", input = "hi"}, TOKEN).status, 400)
	t:eq(stack.server.request_logs_repo:list({}, os.time())[1].error_code, "unsupported_protocol")
	local failed = {id = "resp_failed", status = "failed", error = {code = "rate_limit_exceeded", message = "PRIVATE"}}
	addNative(stack, "failed-native", fakeProvider({response = failed}))
	stack.monitor.refresh = function() end
	t:eq(request(t, stack, "/v1/responses", {model = "lite", input = "hi"}, TOKEN).status, 200)
	local rows = stack.server.request_logs_repo:list({}, os.time())
	t:eq(rows[1].status, 502)
	t:eq(rows[1].error_code, "rate_limit")
	t:eq(rows[1].ttft_ms, nil)
	t:eq(rows[1].output_tps, nil)
	t:eq(json.encode(rows):find("PRIVATE", 1, true), nil)
	stack.server:stop()
	stack.storage:close()
end

return test
