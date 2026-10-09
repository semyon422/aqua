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
		models = {"gpt-6-luna"},
	}, {}, 1000)
	models:create("lite", {"glm-5.3", "gpt-6-luna"}, nil, 1000)
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

	-- lite chain: glm-5.3 (zai-1) fails with transport, falls through to gpt-6-luna
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
	t:eq(serving.models[1], "gpt-6-luna")
	-- the second attempt saw the concrete chain entry as the model
	t:eq(serving.bodies[1].model, "gpt-6-luna")

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

return test
