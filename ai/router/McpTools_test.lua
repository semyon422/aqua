local coext = require("coext")
local socket = require("socket")
local json = require("web.json")
local digest = require("digest")
local Client = require("mcp.Client")
local http_util = require("web.http.util")
local Stack = require("ai.router.testing.Stack")
local OpenAILoginManager = require("ai.router.OpenAILoginManager")
local SubscriptionAuth = require("ai.openai.SubscriptionAuth")

local test = {}

---@param t testing.T
---@param stack ai.router.testing.Stack
---@param callback fun(client: mcp.Client)
local function run(t, stack, callback)
	local failure
	local thread = coext.detach(coroutine.create(function()
		local ok, err = pcall(function()
			local _, port = stack.mcp:getAddress()
			local client = Client({url = ("http://127.0.0.1:%d/mcp"):format(assert(port)), token = stack.token,
				scheduler = stack.scheduler, timeout = 2})
			assert(client:initialize())
			callback(client)
			client:close()
		end)
		if not ok then failure = err end
	end))
	coroutine.resume(thread)
	local deadline = socket.gettime() + 10
	while coroutine.status(thread) ~= "dead" do
		assert(stack.scheduler:update(0.01))
		t:assert(socket.gettime() < deadline)
	end
	if failure then error(failure) end
end

---@param client mcp.Client
---@param name string
---@param args table?
---@return table
local function call(client, name, args)
	local result, err = client:callTool("router_" .. name, args)
	assert(result, tostring(err))
	assert(not result.isError, result.content[1].text)
	return assert(result.structuredContent)
end

---@param t testing.T
function test.users_mutations_and_key_revocation(t)
	local stack = Stack()
	local router, providers, fetchers = stack.server.router, stack.server.providers, stack.monitor.fetchers
	local reloads = 0
	local reload = stack.server.reload
	function stack.server:reload(channels, models)
		reloads = reloads + 1
		return reload(self, channels, models)
	end
	run(t, stack, function(client)
		local listed = assert(client:listTools())
		t:eq(#listed.tools, 18)
		---@type {[string]: boolean}
		local names = {}
		for _, tool in ipairs(listed.tools) do
			t:assert(tool.outputSchema)
			names[tool.name] = true
		end
		for _, action in ipairs({"list", "save", "delete"}) do
			local suffix = action == "list" and "s" or ""
			t:eq(names["router_" .. action .. "_channel" .. suffix], true)
			t:eq(names["router_" .. action .. "_subscription" .. suffix], nil)
		end
		t:eq(client.server_info.name, "ai-router")
		local created = call(client, "create_user", {name = "carol", models = {"lite"}})
		local id = created.user.id
		t:tdeq(created.operation, {persistence = "committed", reload = "not_required"})
		t:assert(#created.api_key >= 32)
		t:tdeq(stack.users:getGrants(id), {"lite"})
		local old_hash = digest.hash("sha256", created.api_key, true)
		t:assert(stack.users:findByKeyHash(old_hash))
		call(client, "update_user", {id = id, disabled = true, max_concurrency = 7, max_rpm = 42, models = {"gpt"}})
		t:eq(stack.users:get(id).disabled, true)
		t:eq(stack.users:get(id).max_concurrency, 7)
		t:eq(stack.users:get(id).max_rpm, 42)
		t:tdeq(stack.users:getGrants(id), {"gpt"})
		call(client, "update_user", {id = id, name = "renamed"})
		t:eq(stack.users:get(id).disabled, true)
		local replacement = call(client, "regenerate_key", {id = id})
		t:ne(replacement.api_key, created.api_key)
		t:eq(stack.users:findByKeyHash(old_hash), nil)
		local users = call(client, "list_users")
		t:eq(users.users[1].key_hash, nil)
		t:eq(users.users[1].api_key, nil)
		local invalid = assert(client:callTool("router_create_user", {name = "rollback", models = {"x", "x"}}))
		t:eq(invalid.isError, true)
		t:eq(stack.users:findByName("rollback"), nil)
		local set_grants = stack.users.setGrants
		stack.users.setGrants = function() error("SQL exception with SECRET-INTERNAL-DETAILS") end
		local rolled_back = assert(client:callTool("router_create_user", {name = "rollback-after-write", models = {"x"}}))
		stack.users.setGrants = set_grants
		t:eq(rolled_back.isError, true)
		t:tdeq(rolled_back.structuredContent.operation, {persistence = "not_committed", reload = "not_attempted"})
		t:eq(stack.users:findByName("rollback-after-write"), nil)
		t:eq(json.encode(rolled_back):find("SECRET-INTERNAL-DETAILS", 1, true), nil)
		local duplicate = assert(client:callTool("router_create_user", {name = "renamed", models = {}}))
		t:eq(duplicate.isError, true)
		call(client, "delete_user", {id = id})
		t:eq(stack.users:get(id), nil)
		t:tdeq(stack.users:getGrants(id), {})
	end)
	t:eq(reloads, 0)
	t:eq(stack.server.router, router)
	t:eq(stack.server.providers, providers)
	t:eq(stack.monitor.fetchers, fetchers)
	stack:close()
end

---@param t testing.T
function test.catalog_validation_redaction_and_patching(t)
	local stack = Stack()
	run(t, stack, function(client)
		local created = call(client, "save_channel", {name = "zai-main", kind = "zai", enabled = false,
			config = {base_url = "https://api.z.ai/api/coding/paas/v4", api_key = "SECRET-UPSTREAM", models = {"glm-5.3"}}, limits = {poll_interval = 80}})
		local id = created.channel.id
		t:tdeq(created.operation, {persistence = "committed", reload = "applied"})
		t:eq(created.channel.enabled, false)
		t:eq(created.channel.config.api_key, nil)
		t:eq(created.channel.has_api_key, true)
		call(client, "save_channel", {id = id, enabled = true, config = {model_redirects = { ["glm-5.3"] = "glm-real" }}})
		t:eq(stack.channels:get(id).config.api_key, "SECRET-UPSTREAM")
		t:eq(stack.server.router.state.public_models["zai-main/glm-5.3"], true)
		t:eq(stack.server.router.state.channels[1].poll_interval, 80)
		local removed, removed_error = client:callTool("router_save_channel", {id = id, priority = 1})
		t:eq(removed, nil)
		t:eq(removed_error.code, -32602)
		removed, removed_error = client:callTool("router_save_channel", {id = id, limits = {five_hour_threshold = 80}})
		t:eq(removed, nil)
		t:eq(removed_error.code, -32602)
		local invalid = assert(client:callTool("router_save_model", {name = "bad", target = "missing-model"}))
		t:eq(invalid.isError, true)
		t:eq(stack.models:findByName("bad"), nil)
		local alias = call(client, "save_model", {name = "lite", target = "zai-main/glm-5.3"}).model
		t:eq(alias.target, "zai-main/glm-5.3")
		t:eq(stack.server.router.state.alias_models.lite, "zai-main/glm-5.3")
		local rejected, schema_error = client:callTool("router_save_model", {name = "removed-chain", chain = {"glm-5.3"}})
		t:eq(rejected, nil)
		t:eq(schema_error.code, -32602)
		rejected, schema_error = client:callTool("router_save_model", {name = "array-target", target = {"glm-5.3", "other"}})
		t:eq(rejected, nil)
		t:eq(schema_error.code, -32602)
		invalid = assert(client:callTool("router_save_model", {name = "nested", target = "lite"}))
		t:eq(invalid.isError, true)
		invalid = assert(client:callTool("router_delete_channel", {id = id}))
		t:eq(invalid.isError, true)
		t:assert(stack.channels:get(id))
		invalid = assert(client:callTool("router_save_channel", {id = id, config = {models = {"other"}, api_key = "NEW-SECRET"}}))
		t:eq(invalid.isError, true)
		t:eq(json.encode(invalid):find("NEW-SECRET", 1, true), nil)
		t:eq(stack.channels:get(id).config.api_key, "SECRET-UPSTREAM")
		t:eq(json.encode(call(client, "list_channels")):find("SECRET-UPSTREAM", 1, true), nil)
		call(client, "save_channel", {id = id, config = {base_url = "https://user:SECRET-URL@example.com/v1?token=secret"}})
		t:eq(call(client, "list_channels").channels[1].config.base_url, "[redacted URL]")
		t:eq(call(client, "list_models").aliases[1].name, "lite")
		call(client, "save_model", {id = alias.id, description = "alias"})
		t:eq(stack.models:get(alias.id).description, "alias")
		call(client, "delete_model", {id = alias.id})
		call(client, "delete_channel", {id = id})
		t:eq(#stack.channels:list(), 0)
	end)
	stack:close()
end

---@param t testing.T
function test.committed_catalog_reload_failure_and_retry(t)
	local stack = Stack()
	run(t, stack, function(client)
		call(client, "save_channel", {name = "original", kind = "openai_compat",
			config = {base_url = "http://localhost/v1", models = {"old"}}})
		local router, providers, fetchers, channels = stack.server.router, stack.server.providers,
			stack.monitor.fetchers, stack.monitor.channels
		local factory = stack.server.provider_factory
		stack.server.provider_factory = function(row)
			if row.name == "saved" then error("SECRET-PROVIDER-EXCEPTION") end
			return factory(row)
		end
		local result = assert(client:callTool("router_save_channel", {name = "saved", kind = "openai_compat",
			config = {base_url = "http://localhost/v1", models = {"new"}}}))
		t:eq(result.isError, true)
		t:tdeq(result.structuredContent.operation, {persistence = "committed", reload = "failed"})
		t:assert(result.structuredContent.channel.id > 0)
		t:eq(json.encode(result):find("SECRET-PROVIDER-EXCEPTION", 1, true), nil)
		t:eq(#stack.channels:list(), 2)
		t:eq(stack.server.router, router)
		t:eq(stack.server.providers, providers)
		t:eq(stack.monitor.fetchers, fetchers)
		t:eq(stack.monitor.channels, channels)
		t:eq(stack.server.router.state.public_models.new, nil)
		t:eq(call(client, "status").catalog_reload_pending, true)
		t:eq(#call(client, "list_channels").channels, 2)
		local retry = assert(client:callTool("router_reload_catalog"))
		t:eq(retry.isError, true)
		t:tdeq(retry.structuredContent.operation, {persistence = "not_attempted", reload = "failed"})
		-- User writes neither reload the catalog nor hide a pending reload.
		local user = call(client, "create_user", {name = "still-usable", models = {"old"}})
		t:eq(user.operation.reload, "not_required")
		t:eq(call(client, "status").catalog_reload_pending, true)
		stack.server.provider_factory = factory
		local applied = call(client, "reload_catalog")
		t:tdeq(applied.operation, {persistence = "not_attempted", reload = "applied"})
		t:eq(call(client, "status").catalog_reload_pending, false)
		t:eq(stack.server.router.state.public_models["saved/new"], true)
		t:eq(#stack.channels:list(), 2)
	end)
	stack:close()
end

---@param t testing.T
function test.rollback_failure_reports_unknown_persistence(t)
	local stack = Stack()
	run(t, stack, function(client)
		local db = stack.users.models.router_users.orm.db
		local exec, set_grants = db.exec, stack.users.setGrants
		function db:exec(query, values)
			if query == "ROLLBACK" then error("SECRET-ROLLBACK-DETAILS") end
			return exec(self, query, values)
		end
		stack.users.setGrants = function() error("SECRET-WRITE-DETAILS") end
		local result = assert(client:callTool("router_create_user", {name = "uncertain", models = {"x"}}))
		db.exec, stack.users.setGrants = exec, set_grants
		db:exec("ROLLBACK")
		t:eq(result.isError, true)
		t:tdeq(result.structuredContent.operation, {persistence = "unknown", reload = "not_attempted"})
		t:eq(json.encode(result):find("SECRET-", 1, true), nil)
		t:eq(stack.users:findByName("uncertain"), nil)
	end)
	stack:close()
end

---@param t testing.T
function test.schema_errors_and_statistics(t)
	local stack = Stack()
	stack.usage_repo:record(os.time(), "alice", 200, "gpt", "gpt", "direct",
		{input_tokens = 10, output_tokens = 5, cached_input_tokens = 2, estimated = false})
	run(t, stack, function(client)
		for _, args in ipairs({{id = 0}, {id = "1"}, {id = 1, unexpected = "SECRET"}, {}}) do
			local result, err = client:callTool("router_delete_user", args)
			t:eq(result, nil)
			t:eq(err.kind, "rpc")
		end
		local result = assert(client:callTool("router_save_channel", {}))
		t:eq(result.isError, true)
		t:eq(#stack.channels:list(), 0)
		local malformed, shape_err = client:callTool("router_create_user", {name = "bad-shape", models = {oops = "gpt"}})
		t:eq(malformed, nil)
		t:eq(shape_err.kind, "rpc")
		t:eq(stack.users:findByName("bad-shape"), nil)
		local usage = call(client, "usage", {hours = 168})
		t:eq(usage.rows[1].input_tokens, 10)
		t:eq(call(client, "status").channels[1], nil)
	end)
	stack:close()
end

---@param t testing.T
function test.openai_device_login_and_pending_guards(t)
	local stack = Stack()
	local pending
	local manager = OpenAILoginManager({scheduler = stack.scheduler, oauth_repo = stack.management.oauth_repo,
		spawn = function(callback) pending = callback end,
		create_auth = function()
			return SubscriptionAuth({scheduler = stack.scheduler,
				credentials = {access_token = "", refresh_token = "", expires_at = 0, account_id = ""},
				save_credentials = function() error("not used") end, open_url = function() return true end,
				request = function() return {status = 404, body = "{}"} end})
		end})
	stack.management.openai_login = manager
	run(t, stack, function(client)
		local row = call(client, "save_channel", {name = "ChatGPT-direct", kind = "openai", config = {models = {"gpt"}}}).channel
		t:eq(row.config.auth_path, nil)
		t:eq(call(client, "start_openai_login", {id = row.id}).login.status, "logging_in")
		t:assert(pending)
		local state = manager:getState(row.id)
		state.user_code, state.verification_url, state.expires_at = "ONE-TIME", "https://auth.openai.com/codex/device", os.time() + 60
		t:eq(call(client, "openai_login_status", {id = row.id}).login.user_code, "ONE-TIME")
		t:eq(call(client, "list_channels").channels[1].login_status, "logging_in")
		t:eq(json.encode(call(client, "list_channels")):find("ONE-TIME", 1, true), nil)
		for _, tool in ipairs({"start_openai_login", "delete_channel", "save_channel"}) do
			local result = assert(client:callTool("router_" .. tool, {id = row.id}))
			t:eq(result.isError, true)
		end
		local rejected, schema_error = client:callTool("router_save_channel", {name = "legacy", kind = "openai",
			config = {auth_path = "legacy.lua", models = {"gpt"}}})
		t:eq(rejected, nil)
		t:eq(schema_error.code, -32602)
		call(client, "refresh_usage", {id = row.id})
		pending()
		t:eq(call(client, "openai_login_status", {id = row.id}).login.status, "error")
		call(client, "delete_channel", {id = row.id})
	end)
	stack:close()
end

---@param t testing.T
function test.transport_authentication_and_origin(t)
	local stack = Stack()
	run(t, stack, function()
		local _, port = stack.mcp:getAddress()
		for _, case in ipairs({
			{headers = {}, status = 401},
			{headers = {Authorization = "Bearer wrong"}, status = 401},
			{headers = {Cookie = "router_admin=not-a-management-credential"}, status = 401},
			{headers = {Authorization = "Bearer " .. stack.token, Origin = "http://localhost"}, status = 403},
		}) do
			local response = assert(http_util.request(("http://127.0.0.1:%d/mcp"):format(port), "{}",
				{method = "POST", headers = case.headers, scheduler = stack.scheduler, timeout = 1}))
			t:eq(response.status, case.status)
		end
	end)
	stack:close()
end

---@param t testing.T
function test.channel_probe_uses_one_native_call_and_only_returns_metadata(t)
	local stack = Stack()
	local calls = 0
	stack.server.provider_factory = function(row)
		if row.kind == "openai" then
			return {createResponse = function(_, body, upstream_model, session_id, callback)
				calls = calls + 1
				t:eq(body.model, "public")
				t:eq(upstream_model, "redirected")
				t:eq(body.store, false)
				t:eq(body.stream, false)
				t:eq(body.max_output_tokens, nil)
				t:eq(session_id, nil)
				t:eq(callback, nil)
				return {status = "completed", output = {{type = "message", content = "PRIVATE-RESPONSE"}},
					usage = {input_tokens = 5, output_tokens = 2, input_tokens_details = {cached_tokens = 1}}}
			end}
		end
		return {complete = function(_, body, upstream_model)
			calls = calls + 1
			t:eq(body.model, "public")
			t:eq(upstream_model, "redirected")
			t:eq(body.max_tokens, 16)
			t:eq(body.stream, false)
			t:eq(body.thinking and body.thinking.type, row.kind == "zai" and "disabled" or nil)
			return {content = "PRIVATE-RESPONSE", usage = {input_tokens = 5, output_tokens = 2, cached_input_tokens = 1}}
		end}
	end
	run(t, stack, function(client)
		local tools = assert(client:listTools())
		for _, tool in ipairs(tools.tools) do
			if tool.name == "router_test_channel" then
				t:eq(tool.annotations.readOnlyHint, false)
				t:eq(tool.annotations.openWorldHint, true)
				t:eq(tool.annotations.destructiveHint, false)
			end
		end
		for _, kind in ipairs({"openai", "zai", "openai_compat"}) do
			local created = call(client, "save_channel", {name = kind, kind = kind, config = {
				models = {"public"}, model_redirects = {public = "redirected"},
				base_url = kind ~= "openai" and "http://localhost:1/v1" or nil,
				api_key = kind ~= "openai" and "PRIVATE-KEY" or nil}})
			local before = calls
			local result = call(client, "test_channel", {id = created.channel.id, model = "public"})
			t:eq(calls, before + 1)
			t:eq(result.probe.ok, true)
			t:eq(result.probe.status, 200)
			t:eq(result.probe.model, kind .. "/public")
			t:eq(result.probe.upstream_model, "redirected")
			t:eq(result.probe.protocol, kind == "openai" and "responses" or "chat_completions")
			t:eq(result.probe.output_tokens, 2)
			t:eq(result.probe.cached_input_tokens, 1)
			t:eq(result.operation, nil)
			t:eq(json.encode(result):find("PRIVATE", 1, true), nil)
		end
	end)
	t:eq(calls, 3)
	t:eq(#stack.usage_repo:history(os.time()).rows, 0)
	t:eq(#stack.server.request_logs_repo:list({}, os.time()), 0)
	t:eq(next(stack.management.active_probes), nil)
	stack:close()
end

---@param t testing.T
function test.channel_probe_validates_selection_and_sanitizes_failures_without_retry(t)
	local stack = Stack()
	local calls = 0
	local mode = "timeout"
	stack.server.provider_factory = function()
		return {complete = function()
			calls = calls + 1
			if mode == "exception" then error("PRIVATE-EXCEPTION") end
			if mode == "auth" then return nil, "PRIVATE", {status = 401, code = "PRIVATE-CODE", message = "PRIVATE"} end
			if mode == "busy" then
				local result, err = stack.management:execute("testChannel", {id = 1, model = "public"}, false)
				t:assert(err)
				t:assert(result.error:find("already running", 1, true))
			end
			return nil, "PRIVATE timeout"
		end}
	end
	run(t, stack, function(client)
		local created = call(client, "save_channel", {name = "proxy", kind = "openai_compat",
			config = {base_url = "http://localhost:1/v1", models = {"public"}}})
		local id = created.channel.id
		for _, args in ipairs({{id = id}, {id = id, model = "public", prompt = "PRIVATE"}}) do
			local result, err = client:callTool("router_test_channel", args)
			t:eq(result, nil)
			t:eq(err.code, -32602)
		end
		for _, args in ipairs({{id = 999, model = "public"}, {id = id, model = "missing"}, {id = id, model = "proxy/public"}}) do
			local result = assert(client:callTool("router_test_channel", args))
			t:eq(result.isError, true)
		end
		t:eq(calls, 0)
		stack.management.catalog_reload_pending = true
		t:eq(assert(client:callTool("router_test_channel", {id = id, model = "public"})).isError, true)
		stack.management.catalog_reload_pending = false
		call(client, "save_channel", {id = id, enabled = false})
		t:eq(assert(client:callTool("router_test_channel", {id = id, model = "public"})).isError, true)
		t:eq(calls, 0)
		call(client, "save_channel", {id = id, enabled = true})
		for _, case in ipairs({{"timeout", "timeout"}, {"auth", "auth"}, {"exception", "upstream_error"}, {"busy", "timeout"}}) do
			mode = case[1]
			local before = calls
			local result = call(client, "test_channel", {id = id, model = "public"})
			t:eq(result.probe.ok, false)
			t:eq(result.probe.error_code, case[2])
			t:eq(result.probe.status, mode == "auth" and 401 or 502)
			t:eq(calls, before + 1)
			t:eq(next(stack.management.active_probes), nil)
			t:eq(json.encode(result):find("PRIVATE", 1, true), nil)
		end
	end)
	stack:close()
end

---@param t testing.T
function test.channel_probe_handles_native_failure_and_blocks_pending_login(t)
	local stack = Stack()
	local calls = 0
	stack.server.provider_factory = function()
		return {createResponse = function()
			calls = calls + 1
			return {status = "failed", error = {code = "rate_limit_exceeded", message = "PRIVATE-ERROR"}}
		end}
	end
	run(t, stack, function(client)
		local id = call(client, "save_channel", {name = "native", kind = "openai", config = {models = {"model"}}}).channel.id
		local result = call(client, "test_channel", {id = id, model = "model"})
		t:eq(result.probe.ok, false)
		t:eq(result.probe.status, 502)
		t:eq(result.probe.error_code, "rate_limit")
		t:eq(result.probe.output_tokens, nil)
		t:eq(json.encode(result):find("PRIVATE", 1, true), nil)
		stack.management.openai_login = {isLoggingIn = function() return true end}
		t:eq(assert(client:callTool("router_test_channel", {id = id, model = "model"})).isError, true)
		stack.management.openai_login = nil
		stack.server.providers[id] = nil
		t:eq(assert(client:callTool("router_test_channel", {id = id, model = "model"})).isError, true)
		t:eq(calls, 1)
	end)
	stack:close()
end

---@param t testing.T
function test.oauth_storage_follows_channel_lifetime_and_never_appears_in_public_results(t)
	local stack = Stack()
	run(t, stack, function(client)
		local channel = call(client, "save_channel", {name = "oauth", kind = "openai", config = {models = {"model"}}}).channel
		local repo = stack.management.oauth_repo
		local credentials = repo:get(channel.id)
		credentials.access_token, credentials.refresh_token = "PRIVATE-ACCESS", "PRIVATE-REFRESH"
		repo:save(channel.id, credentials.generation, credentials)
		local renamed = call(client, "save_channel", {id = channel.id, name = "renamed"})
		t:eq(repo:get(channel.id).refresh_token, "PRIVATE-REFRESH")
		t:eq(json.encode(renamed):find("PRIVATE", 1, true), nil)
		t:eq(json.encode(call(client, "list_channels")):find("PRIVATE", 1, true), nil)
		call(client, "save_channel", {id = channel.id, kind = "openai_compat", config = {models = {"model"}, base_url = "http://localhost:1/v1"}})
		t:has_error(function() repo:get(channel.id) end)
		call(client, "save_channel", {id = channel.id, kind = "openai", config = {models = {"model"}}})
		t:eq(repo:get(channel.id).refresh_token, "")
		t:ne(repo:get(channel.id).generation, credentials.generation)
		call(client, "delete_channel", {id = channel.id})
		t:has_error(function() repo:get(channel.id) end)
	end)
	stack:close()
end

---@param t testing.T
function test.status_exposes_safe_usage_poll_errors_with_schema_validation(t)
	local stack = Stack()
	run(t, stack, function(client)
		local saved = call(client, "save_channel", {name = "openai", kind = "openai", config = {models = {"gpt"}}})
		local id = saved.channel.id
		stack.monitor:setChannels(stack.server.router.state.channels, {[id] = function()
			return nil, "SECRET body and credentials", {code = "cloudflare_challenge", status = 403}
		end})
		stack.monitor:refresh(id, 1234)
		local status = call(client, "status")
		local poll = status.channels[1].usage_poll
		t:eq(poll.attempted_at, 1234)
		t:eq(poll.error.code, "cloudflare_challenge")
		t:eq(poll.error.http_status, 403)
		t:eq(json.encode(status):find("SECRET", 1, true), nil)
	end)
	stack:close()
end

return test
