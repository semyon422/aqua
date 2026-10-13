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
local SubscriptionsRepo = require("ai.router.SubscriptionsRepo")
local ModelsRepo = require("ai.router.ModelsRepo")
local WindowsRepo = require("ai.router.WindowsRepo")
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

-- A fake provider returning a canned canonical message or failures.
---@param opts {message: table?, err: string?, provider_error: table?, deltas: table[]?, fetch_usage: fun(): table?, string?, table?}?
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
---@field subscriptions ai.router.SubscriptionsRepo
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
	local subscriptions = SubscriptionsRepo(storage.models)
	local models = ModelsRepo(storage.models)
	local usage_repo = UsageRepo(storage.models)
	local monitor = UsageMonitor({
		usage_repo = usage_repo,
		windows_repo = WindowsRepo(storage.models),
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
		provider_factory = function(subscription)
			return providers_by_name[subscription.name]
		end,
	})
	local user = users:create("alice", 1000)
	-- deterministic key for tests: overwrite the generated hash
	storage.models.router_users:update(
		{key_hash = digest.hash("sha256", TOKEN, true), key_hint = TOKEN:sub(-4)},
		{id = user.id}
	)
	users:setGrants(user.id, {"glm-5.3", "gpt-6-luna", "lite"})
	subscriptions:create("zai-1", "zai", 1, {
		base_url = "https://api.z.ai/api/coding/paas/v4",
		api_key = "key",
		models = {"glm-5.3"},
	}, {}, 1000)
	subscriptions:create("openai-1", "openai", 2, {
		auth_path = "userdata/unused.lua",
		models = {"gpt-6-luna", "glm-5.3"},
	}, {}, 1000)
	models:create("lite", "glm-5.3", nil, 1000)
	server:reload(subscriptions:list(), models:list())
	local stack = {
		storage = storage,
		server = server,
		scheduler = scheduler,
		users = users,
		subscriptions = subscriptions,
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
---@return {status: integer, body: string}
local function request(t, stack, path, body, token)
	---@type {status: integer, body: string}?
	local response
	---@type string?
	local request_err
	local thread = coext.detach(coroutine.create(function()
		local headers = {}
		if token then headers.Authorization = "Bearer " .. token end
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
		model = "glm-5.3",
		messages = json.array({{role = "user", content = "hi"}}),
	}, TOKEN)
	t:eq(response.status, 200)
	local completion = json.decode(response.body)
	t:eq(completion.model, "glm-5.3")
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
	t:eq(row.model, "glm-5.3")
	t:eq(row.upstream_model, "glm-5.3")
	t:eq(row.subscription, "zai-1")
	t:eq(row.input_tokens, 10)
	t:eq(row.cached_input_tokens, 2)
	t:eq(row.estimated_requests, 0)
	stack.server:stop()
	stack.storage:close()
end

---@param t testing.T
function test.failover_on_transport_error_and_429(t)
	local failing = fakeProvider({err = "upstream request failed"})
	local quota = fakeProvider({provider_error = {
		status = 429, message = "rate limited", type = "rate_limit_error", code = "rate_limit_exceeded",
	}})
	local serving = fakeProvider({message = ok_message})
	local stack = startStack({providers = {["zai-1"] = serving, ["openai-1"] = failing}})
	-- gpt-6-luna lives on openai-1 only: exhausted candidates -> 503
	local response = request(t, stack, "/v1/chat/completions", {
		model = "gpt-6-luna",
		messages = json.array({{role = "user", content = "hi"}}),
	}, TOKEN)
	t:eq(response.status, 503)
	t:eq(json.decode(response.body).error.code, "upstream_unavailable")

	-- The alias stays on glm-5.3 while failing over between subscriptions.
	stack.providers_by_name["zai-1"] = failing
	stack.providers_by_name["openai-1"] = serving
	stack.server:reload(stack.subscriptions:list(), stack.models:list())
	response = request(t, stack, "/v1/chat/completions", {
		model = "lite",
		messages = json.array({{role = "user", content = "hi"}}),
	}, TOKEN)
	t:eq(response.status, 200)
	t:eq(json.decode(response.body).model, "lite")
	-- failing served twice: as openai-1 on the first request and as zai-1 on this one
	t:eq(failing.complete_count, 2)
	t:eq(serving.complete_count, 1)
	t:eq(serving.models[1], "glm-5.3")
	t:eq(serving.bodies[1].model, "glm-5.3")

	-- quota errors advance the walk and refresh the monitor
	stack.providers_by_name["zai-1"] = quota
	stack.server:reload(stack.subscriptions:list(), stack.models:list())
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
	t:eq(response.status, 200)
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
function test.depleted_first_subscription_falls_through(t)
	local depleted = fakeProvider({message = ok_message})
	local serving = fakeProvider({message = ok_message})
	local stack = startStack({providers = {["zai-1"] = depleted, ["openai-1"] = serving}})
	stack.subscriptions:update(1, {limits = {five_hour_threshold = 80}}, 1001)
	stack.server:reload(stack.subscriptions:list(), stack.models:list())
	-- fresh upstream snapshot: zai-1 is 95% full
	stack.monitor:setSubscriptions(stack.server.router.state.subscriptions, {})
	stack.monitor:saveWindow(stack.server.router.state.subscriptions[1], "five_hour",
		{used_percent = 95}, "upstream", os.time())
	local response = request(t, stack, "/v1/chat/completions", {
		model = "lite",
		messages = json.array({{role = "user", content = "hi"}}),
	}, TOKEN)
	t:eq(response.status, 200)
	t:eq(depleted.complete_count, 0)
	t:eq(serving.complete_count, 1)
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
		model = "glm-5.3",
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
	stack.server:reload(stack.subscriptions:list(), stack.models:list())
	response = request(t, stack, "/v1/chat/completions", {
		model = "glm-5.3",
		messages = json.array({{role = "user", content = "hi"}}),
		stream = true,
	}, TOKEN)
	t:eq(response.status, 503)
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
	t:tdeq(ids, {"glm-5.3", "gpt-6-luna", "lite"})

	-- ungranted public model
	response = request(t, stack, "/v1/chat/completions", {
		model = "glm-5.3",
		messages = json.array({{role = "user", content = "hi"}}),
	}, TOKEN)
	t:eq(response.status, 200)
	stack.users:setGrants(stack.user.id, {"lite"})
	stack.server:reload(stack.subscriptions:list(), stack.models:list())
	response = request(t, stack, "/v1/chat/completions", {
		model = "glm-5.3",
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
function test.streaming_failover_only_before_output(t)
	local first = fakeProvider({deltas = {{role = "assistant", content = ""}, {}}, err = "timeout"})
	local second = fakeProvider({deltas = {{content = "hello"}}, message = ok_message})
	local stack = startStack({providers = {["zai-1"] = first, ["openai-1"] = second}})
	local body = {model = "lite", messages = {{role = "user", content = "hi"}}, stream = true}
	local response = request(t, stack, "/v1/chat/completions", body, TOKEN)
	t:eq(response.status, 200)
	t:eq(second.stream_count, 1)
	t:eq(parseSse(response.body)[2].choices[1].delta.content, "hello")
	local row = stack.usage_repo:history(os.time()).rows[1]
	t:eq(row.subscription, "openai-1")
	t:eq(row.upstream_model, "glm-5.3")
	first = fakeProvider({deltas = {{content = "partial"}}, err = "timeout"})
	stack.providers_by_name["zai-1"] = first
	stack.server:reload(stack.subscriptions:list(), stack.models:list())
	response = request(t, stack, "/v1/chat/completions", body, TOKEN)
	t:eq(response.status, 200)
	t:eq(second.stream_count, 1)
	local events = parseSse(response.body)
	t:eq(events[2].choices[1].delta.content, "partial")
	t:eq(events[3].error.code, "upstream_error")
	t:eq(#events, 3)
	t:assert(response.body:find("data: [DONE]", 1, true))
	local rows = stack.usage_repo:history(os.time()).rows
	local errors = 0
	for _, item in ipairs(rows) do errors = errors + item.errors end
	t:eq(errors, 1)
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
	t:eq(request(t, stack, "/v1/chat/completions", body, TOKEN).status, 200)
	local complete = stack.server.complete
	stack.server.complete = function() error("SECRET-HANDLER") end
	local response = request(t, stack, "/v1/chat/completions", body, TOKEN)
	t:eq(response.status, 500)
	t:eq(response.body:find("SECRET", 1, true), nil)
	t:eq(next(stack.server.active_requests), nil)
	stack.server.complete = complete
	t:eq(request(t, stack, "/v1/chat/completions", body, TOKEN).status, 200)
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
function test.authentication_cooldown_expires_and_local_errors_are_counted(t)
	local bad = fakeProvider({provider_error = {status = 401, message = "unauthorized", type = "authentication_error", code = "unauthorized"}})
	local good = fakeProvider({message = ok_message})
	local stack = startStack({providers = {["zai-1"] = bad, ["openai-1"] = good}})
	local now = 1000
	stack.server.get_time = function() return now end
	local body = {model = "lite", messages = {}}
	t:eq(request(t, stack, "/v1/chat/completions", body, TOKEN).status, 200)
	t:eq(stack.server.cooldowns[1], 1600)
	t:eq(request(t, stack, "/v1/chat/completions", body, TOKEN).status, 200)
	t:eq(bad.complete_count, 1)
	now = 1600
	t:eq(request(t, stack, "/v1/chat/completions", body, TOKEN).status, 200)
	t:eq(bad.complete_count, 2)
	stack.server.cooldowns[1] = nil
	stack.providers_by_name["zai-1"] = fakeProvider({provider_error = {
		status = 400, message = "bad request", type = "invalid_request_error", code = "invalid_request"}})
	stack.server:reload(stack.subscriptions:list(), stack.models:list())
	for _, stream in ipairs({false, true}) do
		body.stream = stream
		t:eq(request(t, stack, "/v1/chat/completions", body, TOKEN).status, 400)
	end
	t:eq(good.complete_count, 3)
	local errors = 0
	for _, row in ipairs(stack.usage_repo:history(os.time()).rows) do errors = errors + row.errors end
	t:eq(errors, 2)
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
		t:eq(result.subscription, "zai-1")
		t:eq(fallback.stream_count, 0)
	end
	stack.server:stop()
	stack.storage:close()
end

---@param t testing.T
function test.user_limit_overrides_and_key_rotation_share_counters(t)
	local stack = startStack({providers = {["zai-1"] = fakeProvider({message = ok_message})}})
	stack.users:update(stack.user.id, {max_rpm = 1, max_concurrency = 1}, os.time())
	local body = {model = "glm-5.3", messages = {}}
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
		stack.server:reload(stack.subscriptions:list(), stack.models:list())
		stack.server.cooldowns[1] = nil
		local response = request(t, stack, "/v1/chat/completions", {model = "lite", messages = {}, stream = true}, TOKEN)
		t:eq(response.status, 200)
		t:eq(parseSse(response.body)[2].choices[1].delta.content, "hello")
		if mode == "auth" then t:assert(stack.server.cooldowns[1]) end
		t:eq(next(stack.server.active_requests), nil)
	end
	t:eq(closed, 2)
	t:eq(fallback.stream_count, 2)
	upstream:stop()
	stack.server:stop()
	stack.storage:close()
end

---@param t testing.T
function test.pre_output_failures_visit_each_candidate_once(t)
	for _, stream in ipairs({false, true}) do
		for _, code in ipairs({429, 500, 503}) do
			local first = fakeProvider({provider_error = {status = code, message = "failed", type = "upstream_error", code = "failed"}})
			local second = fakeProvider({err = "timeout"})
			local stack = startStack({providers = {["zai-1"] = first, ["openai-1"] = second}})
			local refreshed = 0
			stack.monitor.refresh = function(_, id) t:eq(id, 1) refreshed = refreshed + 1 end
			local response = request(t, stack, "/v1/chat/completions", {model = "lite", stream = stream, messages = {}}, TOKEN)
			t:eq(response.status, 503)
			t:eq(first.complete_count + first.stream_count, 1)
			t:eq(second.complete_count + second.stream_count, 1)
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
	stack.server:reload(stack.subscriptions:list(), stack.models:list())
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
	upstream:stop()
	stack.server:stop()
	stack.storage:close()
end

---@param t testing.T
function test.alias_never_falls_back_to_another_model(t)
	local failing = fakeProvider({err = "unavailable"})
	local other = fakeProvider({message = ok_message})
	local stack = startStack({providers = {["zai-1"] = failing, ["openai-1"] = other}})
	stack.subscriptions:update(2, {config = {auth_path = "userdata/unused.lua", models = {"gpt-6-luna"}}}, 1001)
	stack.server:reload(stack.subscriptions:list(), stack.models:list())
	stack.users:setGrants(stack.user.id, {"lite"})
	stack.providers_by_name["zai-1"] = fakeProvider({message = ok_message})
	stack.server:reload(stack.subscriptions:list(), stack.models:list())
	local response = request(t, stack, "/v1/chat/completions", {model = "lite", messages = {}}, TOKEN)
	t:eq(response.status, 200)
	t:eq(json.decode(response.body).model, "lite")
	stack.providers_by_name["zai-1"] = failing
	stack.server:reload(stack.subscriptions:list(), stack.models:list())
	for _, stream in ipairs({false, true}) do
		local response = request(t, stack, "/v1/chat/completions", {model = "lite", messages = {}, stream = stream}, TOKEN)
		t:eq(response.status, 503)
	end
	t:eq(other.complete_count, 0)
	t:eq(other.stream_count, 0)
	stack.server:stop()
	stack.storage:close()
end

return test
