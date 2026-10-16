local coext = require("coext")
local socket = require("socket")
local http_util = require("web.http.util")
local json = require("web.json")
local Stack = require("ai.router.testing.Stack")
local OpenAILoginManager = require("ai.router.OpenAILoginManager")

local test = {}

---@param t testing.T
---@param stack ai.router.testing.Stack
---@param method web.HttpMethod
---@param path string
---@param form table?
---@param cookie string?
---@return {status: integer, headers: web.Headers, body: string}
local function request(t, stack, method, path, form, cookie)
	local response, request_err
	local thread = coext.detach(coroutine.create(function()
		local headers = {}
		if cookie then headers.Cookie = cookie end
		if form then headers["Content-Type"] = "application/x-www-form-urlencoded" end
		local _, port = stack.server:getAddress()
		response, request_err = http_util.request(("http://127.0.0.1:%d%s"):format(assert(port), path),
			form and http_util.encode_query_string(form) or nil,
			{method = method, headers = headers, scheduler = stack.scheduler, timeout = 1})
	end))
	coroutine.resume(thread)
	local deadline = socket.gettime() + 3
	while coroutine.status(thread) ~= "dead" do
		assert(stack.scheduler:update(0.01))
		t:assert(socket.gettime() < deadline)
	end
	t:eq(request_err, nil)
	return assert(response)
end

---@param t testing.T
---@param stack ai.router.testing.Stack
---@return string
---@return string
local function login(t, stack)
	local response = request(t, stack, "POST", "/admin/login", {password = stack.password})
	t:eq(response.status, 303)
	t:eq(response.headers:get("Location"), "/admin/overview")
	local set_cookie = assert(response.headers:get("Set-Cookie"))
	t:assert(set_cookie:find("Path=/;", 1, true))
	local cookie = assert(set_cookie:match("(router_admin=[^;]+)"))
	response = request(t, stack, "GET", "/admin/users", nil, cookie)
	return cookie, assert(response.body:match('name="csrf_token" value="([^"]+)"'))
end

---@param t testing.T
function test.login_flow_and_csrf(t)
	local stack = Stack()
	local response = request(t, stack, "GET", "/admin/users")
	t:eq(response.status, 303)
	t:eq(response.headers:get("Location"), "/admin")
	response = request(t, stack, "POST", "/admin/login", {password = "wrong"})
	t:eq(response.status, 401)
	local cookie, csrf = login(t, stack)
	response = request(t, stack, "POST", "/admin/logout", {csrf_token = "wrong"}, cookie)
	t:eq(response.status, 403)
	response = request(t, stack, "POST", "/admin/logout", {csrf_token = csrf}, cookie)
	t:eq(response.status, 303)
	t:assert(response.headers:get("Set-Cookie"):find("Max-Age=0", 1, true))
	stack:close()
end

---@param t testing.T
function test.users_display_grants_and_hide_keys(t)
	local stack = Stack()
	local user, key = stack.users:create("carol", os.time())
	stack.users:setGrants(user.id, {"lite"})
	local cookie = login(t, stack)
	local response = request(t, stack, "GET", "/admin/users", nil, cookie)
	t:eq(response.status, 200)
	t:assert(response.body:find("carol", 1, true))
	t:assert(response.body:find("lite", 1, true))
	t:eq(response.body:find(key, 1, true), nil)
	t:eq(response.body:find(user.key_hash, 1, true), nil)
	stack:close()
end

---@param t testing.T
function test.catalog_pages_display_models_and_hide_credentials(t)
	local stack = Stack()
	stack.channels:create("local", "openai_compat", {
		base_url = "http://127.0.0.1:18020/v1", api_key = "PRIVATE-UPSTREAM-KEY", models = {"qwen", "org/model"},
		model_redirects = {qwen = "qwen-real"},
	}, {}, os.time())
	stack.models:create("lite", "local/qwen", "Simple alias", os.time())
	stack.server:reload(stack.channels:list(), stack.models:list())
	local cookie = login(t, stack)
	local response = request(t, stack, "GET", "/admin/channels", nil, cookie)
	t:eq(response.status, 200)
	t:assert(response.body:find("local", 1, true))
	t:assert(response.body:find("qwen", 1, true))
	t:assert(response.body:find("qwen → qwen-real", 1, true))
	t:assert(response.body:find("org/model", 1, true))
	t:eq(response.body:find("local/qwen", 1, true), nil)
	t:eq(response.body:find("(upstream)", 1, true), nil)
	t:eq(response.body:find('href="/admin/status"', 1, true), nil)
	t:eq(response.body:find("PRIVATE-UPSTREAM-KEY", 1, true), nil)
	response = request(t, stack, "GET", "/admin/models", nil, cookie)
	t:eq(response.status, 200)
	t:assert(response.body:find("lite", 1, true))
	t:assert(response.body:find("qwen", 1, true))
	t:assert(response.body:find("Simple alias", 1, true))
	stack:close()
end

---@param t testing.T
function test.read_only_boundary(t)
	local stack = Stack()
	local cookie, csrf = login(t, stack)
	local response = request(t, stack, "POST", "/admin/users", {csrf_token = csrf, name = "must-not-create"}, cookie)
	t:eq(response.status, 405)
	t:eq(response.headers:get("Allow"), "GET")
	t:eq(#stack.users:list(), 0)
	for _, path in ipairs({"users", "channels", "models", "usage"}) do
		response = request(t, stack, "GET", "/admin/" .. path, nil, cookie)
		local _, forms = response.body:gsub("<form[%s>]", "")
		t:eq(forms, 1)
		t:assert(response.body:find('action="/admin/logout"', 1, true))
	end
	stack:close()
end

---@param t testing.T
function test.usage_and_channels_pages_render(t)
	local stack = Stack()
	local cookie = login(t, stack)
	stack.usage_repo:record(os.time(), "alice", 200, "glm-5.3", "glm-5.3", "zai-1",
		{input_tokens = 10, output_tokens = 5, cached_input_tokens = 2, estimated = false})
	local response = request(t, stack, "GET", "/admin/usage?hours=168", nil, cookie)
	t:eq(response.status, 200)
	t:assert(response.body:find("By user", 1, true))
	t:assert(response.body:find("alice", 1, true))
	t:assert(response.body:find("0.0000", 1, true))
	response = request(t, stack, "GET", "/admin/channels", nil, cookie)
	t:eq(response.status, 200)
	t:assert(response.body:find("<h1>Channels</h1>", 1, true))
	response = request(t, stack, "GET", "/admin/unknown", nil, cookie)
	t:eq(response.status, 404)
	stack:close()
end

---@param t testing.T
function test.openai_status_display_hides_verification_code(t)
	local stack = Stack()
	local manager = OpenAILoginManager({scheduler = stack.scheduler,
		create_auth = function() error("dashboard must not start authorization") end})
	function manager:getState(channel_id)
		t:eq(channel_id, 1)
		return {status = "logging_in", user_code = "PRIVATE-CODE", verification_url = "https://auth.openai.com/codex/device"}
	end
	stack.admin.openai_login = manager
	stack.channels:create("direct", "openai", {models = {"gpt"}}, {}, os.time())
	stack.server:reload(stack.channels:list(), {})
	local cookie = login(t, stack)
	local response = request(t, stack, "GET", "/admin/channels", nil, cookie)
	t:assert(response.body:find("logging_in", 1, true))
	t:assert(response.body:find('<td>openai\n\n<div class="muted">logging_in</div>', 1, true))
	t:eq(response.body:find("<th>OpenAI login</th>", 1, true), nil)
	t:eq(response.body:find("PRIVATE-CODE", 1, true), nil)
	t:eq(response.headers:get("Cache-Control"), "no-store")
	stack:close()
end

---@param t testing.T
function test.channels_combine_quotas_freshness_resets_and_local_estimates(t)
	local stack = Stack()
	stack.channels:create("proxy", "openai_compat", {base_url = "http://localhost/v1", models = {"qwen"}}, {}, 1000)
	stack.channels:create("disabled", "openai_compat", {base_url = "http://localhost/v1", models = {"other"}}, {}, 1000)
	stack.channels:update(2, {enabled = false}, 1001)
	stack.server:reload(stack.channels:list(), {})
	stack.admin.get_time = function() return 2000 end
	stack.monitor.windows[1] = {
		five_hour = {used_percent = 0, source = "upstream", updated_at = 1985, reset_at = 3000},
		weekly = {used_percent = 40, used_tokens = 80, quota_tokens = 200, source = "local", updated_at = 1995},
	}
	local cookie = login(t, stack)
	local response = request(t, stack, "GET", "/admin/channels", nil, cookie)
	t:eq(response.status, 200)
	for _, text in ipairs({"0.0%", "40.0%", "80 / 200 tokens", "local estimate", "updated 15s ago",
		"updated 5s ago", "resets " .. os.date("%Y-%m-%d %H:%M", 3000), "disabled", "no"}) do
		t:assert(response.body:find(text, 1, true))
	end
	t:eq(response.body:find("upstream", 1, true), nil)
	t:eq(response.body:find("proxy/qwen", 1, true), nil)
	stack:close()
end

---@param t testing.T
function test.retired_dashboard_pages_redirect_to_channels(t)
	local stack = Stack()
	local cookie = login(t, stack)
	for _, path in ipairs({"/admin/subscriptions", "/admin/status"}) do
		local response = request(t, stack, "GET", path, nil, cookie)
		t:eq(response.status, 303)
		t:eq(response.headers:get("Location"), "/admin/channels")
		response = request(t, stack, "POST", path, {name = "forbidden"}, cookie)
		t:eq(response.status, 405)
	end
	stack:close()
end

---@param t testing.T
function test.zai_key_status_is_muted_in_kind_column_and_hides_key(t)
	local stack = Stack()
	stack.channels:create("glm", "zai", {
		base_url = "https://api.z.ai/api/coding/paas/v4", api_key = "PRIVATE-ZAI-KEY", models = {"glm-5.3"},
	}, {}, os.time())
	stack.server:reload(stack.channels:list(), {})
	local cookie = login(t, stack)
	local response = request(t, stack, "GET", "/admin/channels", nil, cookie)
	t:eq(response.status, 200)
	t:assert(response.body:find('<td>zai\n\n<div class="muted">API key configured</div>', 1, true))
	t:eq(response.body:find("PRIVATE-ZAI-KEY", 1, true), nil)
	t:eq(response.body:find("<th>OpenAI login</th>", 1, true), nil)
	stack:close()
end

---@param t testing.T
function test.request_log_page_is_authenticated_filtered_paginated_and_escaped(t)
	local stack = Stack()
	local repo = stack.server.request_logs_repo
	repo.page_size = 2
	for index = 1, 4 do
		repo:record({created_at = os.time(), user = "alice", model = "<script>private</script>",
			channel = "zai", upstream_model = "glm", protocol = "chat_completions", stream = index == 1,
			status = index == 4 and 200 or 502, duration_ms = 1250,
			ttft_ms = 123, error_code = index < 4 and "timeout" or nil,
			input_tokens = 10, cached_input_tokens = 2, output_tokens = 5, estimated = index == 3})
	end
	local response = request(t, stack, "GET", "/admin/requests")
	t:eq(response.status, 303)
	local cookie = login(t, stack)
	response = request(t, stack, "GET", "/admin/requests?user=alice&channel=zai&outcome=error", nil, cookie)
	t:eq(response.status, 200)
	t:assert(response.body:find("<h1>Requests</h1>", 1, true))
	t:assert(response.body:find("~10", 1, true))
	t:assert(response.body:find("1.250s", 1, true))
	t:assert(response.body:find('<th scope="col">TTFT</th>', 1, true))
	t:assert(response.body:find('<th scope="col">Tokens/s</th>', 1, true))
	t:assert(response.body:find("0.123s", 1, true))
	t:assert(response.body:find('title="The upstream request exceeded its deadline.">timeout</div>', 1, true))
	t:assert(response.body:find('<div class="muted">→ glm</div>', 1, true))
	t:assert(response.body:find("Chat Completions · JSON", 1, true))
	t:eq(response.body:find('<th scope="col">Upstream model</th>', 1, true), nil)
	t:eq(response.body:find("<th>Stream</th>", 1, true), nil)
	t:assert(response.body:find("&lt;script&gt;private&lt;/script&gt;", 1, true))
	t:eq(response.body:find("<script>private</script>", 1, true), nil)
	t:eq(response.body:find(">200</td>", 1, true), nil)
	local older = assert(response.body:match('href="([^"]+)">Older')):gsub("&amp;", "&")
	t:assert(older:find("channel=zai", 1, true))
	t:assert(older:find("outcome=error", 1, true))
	response = request(t, stack, "GET", older, nil, cookie)
	t:eq(response.status, 200)
	t:assert(response.body:find(">1</td>", 1, true))
	t:eq(response.body:find("Older →", 1, true), nil)
	response = request(t, stack, "GET", "/admin/requests?user=missing&before=invalid", nil, cookie)
	t:assert(response.body:find("No requests found.", 1, true))
	response = request(t, stack, "POST", "/admin/requests", {name = "forbidden"}, cookie)
	t:eq(response.status, 405)
	t:eq(#stack.storage.db:query("SELECT * FROM router_request_logs"), 4)
	stack:close()
end

---@param t testing.T
function test.requests_hide_redundant_upstream_names_and_combine_protocol_transport(t)
	local stack = Stack()
	for _, model in ipairs({"openai/model", "alias"}) do
		stack.server.request_logs_repo:record({created_at = os.time(), user = "alice", model = model,
			channel = "openai", upstream_model = "model", protocol = "responses", stream = true,
			status = 200, duration_ms = 1000, input_tokens = 1, output_tokens = 1,
			cached_input_tokens = 0, estimated = false})
	end
	local cookie = login(t, stack)
	local response = request(t, stack, "GET", "/admin/requests", nil, cookie)
	t:eq(response.status, 200)
	local _, count = response.body:gsub('<div class="muted">→ model</div>', "")
	t:eq(count, 1)
	t:assert(response.body:find("Responses · SSE", 1, true))
	t:assert(response.body:find('<th scope="col">Channel</th><th scope="col">Model</th>', 1, true))
	t:assert(response.body:find('<td>openai</td>\n<td><span title="openai/model">model</span>', 1, true))
	t:assert(response.body:find('<td>openai</td>\n<td><span title="alias">alias</span>', 1, true))
	t:eq(response.body:find("<td>openai/model</td>", 1, true), nil)
	t:eq(response.body:find("<th>Stream</th>", 1, true), nil)
	stack:close()
end

---@param t testing.T
function test.requests_strip_only_channel_prefix_and_keep_qualified_model_filters(t)
	local stack = Stack()
	stack.server.request_logs_repo:record({created_at = os.time(), user = "alice", model = "proxy/org/model",
		channel = "proxy", upstream_model = "org/model", protocol = "chat_completions", stream = false,
		status = 200, duration_ms = 1000, input_tokens = 1, output_tokens = 1,
		cached_input_tokens = 0, estimated = false})
	local cookie = login(t, stack)
	local response = request(t, stack, "GET", "/admin/requests?model=proxy%2Forg%2Fmodel", nil, cookie)
	t:eq(response.status, 200)
	t:assert(response.body:find('<td>proxy</td>\n<td><span title="proxy/org/model">org/model</span>', 1, true))
	t:assert(response.body:find('value="proxy/org/model"', 1, true))
	t:eq(response.body:find('<div class="muted">→ org/model</div>', 1, true), nil)
	t:eq(stack.server.request_logs_repo:list({}, os.time())[1].model, "proxy/org/model")
	stack:close()
end

---@param t testing.T
function test.channels_show_poll_failure_staleness_and_recovery(t)
	local stack = Stack()
	stack.channels:create("openai", "openai", {models = {"gpt"}}, {}, 1000)
	stack.server:reload(stack.channels:list(), {})
	stack.admin.get_time = function() return 2000 end
	local channel = stack.server.router.state.channels[1]
	stack.monitor:pollFailed(channel, 1990, "cloudflare_challenge", 403)
	local cookie = login(t, stack)
	local response = request(t, stack, "GET", "/admin/channels", nil, cookie)
	for _, text in ipairs({"Usage polling", "Cloudflare blocked", "HTTP 403", "attempted 10s ago",
		"No successful quota update yet.", "Existing quota values may be stale."}) do
		t:assert(response.body:find(text, 1, true))
	end
	stack.monitor.poll_status[1] = {attempted_at = 1995, succeeded_at = 1995}
	response = request(t, stack, "GET", "/admin/channels", nil, cookie)
	t:assert(response.body:find("<div>OK</div>", 1, true))
	t:assert(response.body:find("last success 5s ago", 1, true))
	t:eq(response.body:find("Cloudflare blocked", 1, true), nil)
	stack:close()
end

---@param t testing.T
function test.overview_authentication_navigation_and_empty_state(t)
	local stack = Stack()
	local response = request(t, stack, "GET", "/admin/overview")
	t:eq(response.status, 303)
	t:eq(response.headers:get("Location"), "/admin")
	local cookie = login(t, stack)
	response = request(t, stack, "GET", "/admin", nil, cookie)
	t:eq(response.headers:get("Location"), "/admin/overview")
	response = request(t, stack, "GET", "/admin/overview", nil, cookie)
	t:eq(response.status, 200)
	for _, text in ipairs({"No channels yet", "router_save_channel", "Enabled channels", "Public models",
		'href="/admin/overview" aria-current="page"', 'name="viewport"', 'aria-label="Color theme"'}) do
		t:assert(response.body:find(text, 1, true), text)
	end
	t:eq(response.headers:get("Cache-Control"), "no-store")
	response = request(t, stack, "POST", "/admin/overview", {name = "forbidden"}, cookie)
	t:eq(response.status, 405)
	stack:close()
end

---@param t testing.T
function test.overview_quota_states_escaping_and_secret_isolation(t)
	local stack = Stack()
	local user, key = stack.users:create("operator", 1000)
	stack.channels:create("glm", "zai", {base_url = "https://example.com/v1",
		api_key = "SECRET-UPSTREAM", models = {"model"}}, {}, 1000)
	stack.channels:create("local", "openai_compat", {base_url = "http://localhost/v1", models = {"qwen"}}, {}, 1000)
	stack.channels:create("disabled", "openai_compat", {base_url = "http://localhost/v1", models = {"hidden"}}, {}, 1000)
	stack.channels:update(3, {enabled = false}, 1001)
	stack.server:reload(stack.channels:list(), {})
	stack.admin.get_time = function() return 2000 end
	stack.monitor.windows[1] = {
		five_hour = {used_percent = 0, source = "upstream", updated_at = 1990},
		weekly = {used_percent = 110, source = "upstream", updated_at = 1990, reset_at = 3000},
	}
	stack.monitor.windows[2] = {five_hour = {used_percent = 25, source = "local", updated_at = 1990}}
	stack.monitor.poll_status[1] = {attempted_at = 1995, succeeded_at = 1990,
		error = {code = "upstream_http", message = "Error <script>alert(1)</script>", http_status = 503}}
	local cookie = login(t, stack)
	local response = request(t, stack, "GET", "/admin/overview", nil, cookie)
	t:eq(response.status, 200)
	for _, text in ipairs({"0.0%", "110.0%", 'value="100"', "HTTP 503", "Quota data may be stale",
		'Last poll <span data-age="1995">5s ago</span>', 'Last successful update <span data-age="1990">10s ago</span>', "Resets", "No quota data available",
		"Monitoring disabled", "OpenAI-compatible", "of 3 configured", "Local estimate",
		"<dt>Public models</dt><dd>2</dd>", "<dt>Users</dt><dd>1</dd>"}) do
		t:assert(response.body:find(text, 1, true), text)
	end
	for _, secret in ipairs({"SECRET-UPSTREAM", key, user.key_hash, "<script>alert(1)</script>"}) do
		t:eq(response.body:find(secret, 1, true), nil)
	end
	t:assert(response.body:find("&lt;script&gt;", 1, true))
	stack:close()
end

---@param t testing.T
function test.overview_json_requires_cookie_and_is_read_only(t)
	local stack = Stack()
	local path = "/admin/overview/data"
	local response = request(t, stack, "GET", path)
	t:eq(response.status, 401)
	t:eq(response.headers:get("Location"), nil)
	t:assert(response.headers:get("Content-Type"):find("application/json", 1, true))
	t:eq(json.decode(response.body).error, "Sign in to view the dashboard.")
	local cookie = login(t, stack)
	response = request(t, stack, "POST", path, {name = "forbidden"}, cookie)
	t:eq(response.status, 405)
	t:eq(response.headers:get("Allow"), "GET")
	t:eq(json.decode(response.body).error, "Read-only dashboard.")
	stack.admin.get_time = function() return os.time() + 13 * 3600 end
	response = request(t, stack, "GET", path, nil, cookie)
	t:eq(response.status, 401)
	t:eq(response.headers:get("Location"), nil)
	stack:close()
end

---@param t testing.T
function test.overview_json_reuses_safe_ssr_without_polling_upstream(t)
	local stack = Stack()
	local user, key = stack.users:create("operator", 1000)
	stack.channels:create("glm", "zai", {base_url = "https://example.com/v1", api_key = "PRIVATE-UPSTREAM",
		models = {"glm"}}, {}, 1000)
	stack.server:reload(stack.channels:list(), {})
	stack.monitor.refresh = function() error("dashboard must not poll upstream") end
	stack.admin.get_time = function() return 2000 end
	stack.monitor.windows[1] = {five_hour = {used_percent = 0, source = "upstream", updated_at = 1990, reset_at = 2005}}
	stack.monitor.poll_status[1] = {attempted_at = 1995, error = {code = "upstream_http", http_status = 503,
		message = "<script>UNTRUSTED</script>"}}
	local cookie = login(t, stack)
	local response = request(t, stack, "GET", "/admin/overview/data", nil, cookie)
	t:eq(response.status, 200)
	t:eq(response.headers:get("Cache-Control"), "no-store")
	local data = json.decode(response.body)
	t:eq(data.now, 2000)
	t:assert(data.html:find('data-overview-now="2000"', 1, true))
	t:assert(data.html:find('data-reset-at="2005"', 1, true))
	t:assert(data.html:find("&lt;script&gt;UNTRUSTED&lt;/script&gt;", 1, true))
	for _, secret in ipairs({key, user.key_hash, "PRIVATE-UPSTREAM", stack.token, 'name="csrf_token"', "<script>"}) do
		t:eq(response.body:find(secret, 1, true), nil)
	end
	stack.monitor.windows[1].five_hour.used_percent = 45
	response = request(t, stack, "GET", "/admin/overview/data", nil, cookie)
	t:assert(json.decode(response.body).html:find("45.0%", 1, true))
	response = request(t, stack, "GET", "/admin/overview", nil, cookie)
	t:assert(response.body:find('id="overview-status"', 1, true))
	t:assert(response.body:find('/admin/overview/data', 1, true))
	response = request(t, stack, "GET", "/admin/channels", nil, cookie)
	t:eq(response.body:find('/admin/overview/data', 1, true), nil)
	stack:close()
end

---@param t testing.T
function test.usage_charts_periods_ssr_escaping_and_authentication(t)
	local stack = Stack()
	stack.admin.get_time = function() return 200 * 3600 + 900 end
	local response = request(t, stack, "GET", "/admin/usage")
	t:eq(response.status, 303)
	local cookie = login(t, stack)
	local counters = {input_tokens = 10, output_tokens = 5, cached_input_tokens = 2, estimated = true}
	stack.usage_repo:record(176 * 3600, "older-week-only", 200, "m", "u", "c", counters)
	stack.usage_repo:record(177 * 3600, "first-hour", 200, "m", "u", "c", counters)
	stack.usage_repo:record(200 * 3600, '<script>PRIVATE-XSS</script>', 500, 'model"<tag>', "u", "c", counters)
	for _, hours in ipairs({24, 168}) do
		response = request(t, stack, "GET", "/admin/usage?hours=" .. hours, nil, cookie)
		t:eq(response.status, 200)
		t:eq(response.headers:get("Cache-Control"), "no-store")
		local _, hourly_rows = response.body:gsub('<tr data%-hour=', "")
		t:eq(hourly_rows, hours)
		local _, svg_count = response.body:gsub('<svg ', "")
		t:eq(svg_count, 2)
		t:assert(response.body:find("Requests &amp; errors", 1, true))
		t:assert(response.body:find("Cached input is included in input tokens", 1, true))
		t:assert(response.body:find("Configured prices only", 1, true))
		t:assert(response.body:find("current hour is partial", 1, true))
		t:assert(response.body:find("&lt;script&gt;PRIVATE-XSS&lt;/script&gt;", 1, true))
		t:eq(response.body:find("<script>PRIVATE-XSS</script>", 1, true), nil)
		t:assert(response.body:find('href="/admin/usage?hours=' .. hours .. '" aria-current="page"', 1, true))
		t:eq(not not response.body:find("older-week-only", 1, true), hours == 168)
		for points in response.body:gmatch('points="([^"]+)"') do
			t:eq(points:find("nan"), nil)
			t:eq(points:find("inf"), nil)
		end
	end
	response = request(t, stack, "GET", "/admin/usage?hours=invalid", nil, cookie)
	local _, hourly_rows = response.body:gsub('<tr data%-hour=', "")
	t:eq(hourly_rows, 24)
	response = request(t, stack, "POST", "/admin/usage", {name = "must-not-mutate"}, cookie)
	t:eq(response.status, 405)
	stack:close()
end

---@param t testing.T
function test.request_filters_survive_pagination_latest_and_individual_removal(t)
	local stack = Stack()
	local repo = stack.server.request_logs_repo
	repo.page_size = 2
	local user, model, channel = 'alice & "ops"', "proxy/org/model", "proxy"
	for _ = 1, 3 do
		repo:record({created_at = os.time(), user = user, model = model, channel = channel,
			upstream_model = "org/model", protocol = "chat_completions", stream = false, status = 502,
			duration_ms = 1000, input_tokens = 1, output_tokens = 0, cached_input_tokens = 0, estimated = true})
	end
	local cookie = login(t, stack)
	local query = http_util.encode_query_string({user = user, model = model, channel = channel, outcome = "error"})
	local response = request(t, stack, "GET", "/admin/requests?" .. query, nil, cookie)
	t:eq(response.status, 200)
	t:assert(response.body:find('<datalist id="request-models"><option value="proxy/org/model">', 1, true))
	t:assert(response.body:find('value="alice &amp; &quot;ops&quot;"', 1, true))
	---@type string
	local older = assert(response.body:match('href="([^"]+)">Older')):gsub("&amp;", "&")
	response = request(t, stack, "GET", older, nil, cookie)
	t:eq(response.status, 200)
	t:assert(response.body:find("Older results", 1, true))
	---@type string
	local latest = assert(response.body:match('href="([^"]+)">Latest</a>')):gsub("&amp;", "&")
	local latest_query = http_util.decode_query_string(latest:match("%?(.+)$"))
	t:tdeq(latest_query, {user = user, model = model, channel = channel, outcome = "error"})
	---@type string
	local remove = assert(response.body:match('href="([^"]+)" aria%-label="Remove user filter:')):gsub("&amp;", "&")
	local remove_query = http_util.decode_query_string(remove:match("%?(.+)$"))
	t:tdeq(remove_query, {model = model, channel = channel, outcome = "error"})
	t:eq(response.body:find('name="before"', 1, true), nil)
	response = request(t, stack, "GET", latest, nil, cookie)
	t:assert(response.body:find("Latest requests", 1, true))
	t:assert(response.body:find("Showing 2 completed requests", 1, true))
	stack:close()
end

---@param t testing.T
function test.request_columns_show_safe_metrics_unknowns_and_escaped_suggestions(t)
	local stack = Stack()
	local repo = stack.server.request_logs_repo
	local now = os.time()
	repo:record({created_at = now, user = '<script>UNTRUSTED</script>', model = 'alias"<tag>',
		channel = "historical-deleted-channel", upstream_model = "org/model", protocol = "responses", stream = true,
		status = 200, duration_ms = 2250, ttft_ms = 250, generation_ms = 2000,
		input_tokens = 10, output_tokens = 5, cached_input_tokens = 3, estimated = false})
	repo:record({created_at = now, user = "alice", model = "alias", channel = "", upstream_model = "",
		protocol = "chat_completions", stream = false, status = 502, duration_ms = 1000,
		input_tokens = 0, output_tokens = 0, cached_input_tokens = 0, estimated = true})
	local cookie = login(t, stack)
	local response = request(t, stack, "GET", "/admin/requests", nil, cookie)
	for _, text in ipairs({'<th scope="col">TTFT</th>', '<th scope="col">Tokens/s</th>',
		'<td>0.250s</td>\n<td>2.5</td>', '<td>—</td>\n<td>—</td>',
		'>Not recorded</div>',
		'title="alias&quot;&lt;tag&gt;">alias&quot;&lt;tag&gt;</span>', '<div class="muted">→ org/model</div>',
		'<td>~0</td>',
		'<option value="&lt;script&gt;UNTRUSTED&lt;/script&gt;">', 'historical-deleted-channel',
		'title="No detailed category recorded. Raw upstream errors are not stored."'}) do
		t:assert(response.body:find(text, 1, true), text)
	end
	t:eq(response.body:find('<details class="request-details">', 1, true), nil)
	---@type string
	local headers = assert(response.body:match('<thead>(.-)</thead>'))
	local _, column_count = headers:gsub('<th scope="col">', "")
	t:eq(column_count, 13)
	for _, label in ipairs({"Generation interval", "Count source", "Requested model", "Upstream model", "Error category", "Error explanation"}) do
		t:eq(headers:find(label, 1, true), nil)
	end
	t:eq(response.body:find('<script>UNTRUSTED</script>', 1, true), nil)
	t:eq(#stack.storage.db:query("SELECT * FROM router_request_logs"), 2)
	response = request(t, stack, "GET", "/admin/requests?before=nan&outcome=invalid&model=" .. string.rep("x", 194), nil, cookie)
	t:eq(response.status, 200)
	t:assert(response.body:find("Showing 2 completed requests", 1, true))
	stack:close()
end

---@param t testing.T
function test.request_cached_input_shows_muted_percentage(t)
	local stack = Stack()
	---@type {input: integer, cached: integer, estimated: boolean}[]
	local cases = {{input = 0, cached = 0, estimated = false}, {input = 10, cached = 3, estimated = false},
		{input = 10, cached = 10, estimated = false}, {input = 10, cached = 0, estimated = true}}
	for _, counts in ipairs(cases) do
		stack.server.request_logs_repo:record({created_at = os.time(), user = "alice", model = "m",
			channel = "c", upstream_model = "m", protocol = "responses", stream = false,
			status = 200, duration_ms = 100, input_tokens = counts.input, cached_input_tokens = counts.cached,
			output_tokens = 1, estimated = counts.estimated})
	end
	local cookie = login(t, stack)
	local response = request(t, stack, "GET", "/admin/requests", nil, cookie)
	for _, cell in ipairs({'0 <span class="muted">(—)</span>', '3 <span class="muted">(30.0%)</span>',
		'10 <span class="muted">(100.0%)</span>', '~0 <span class="muted">(~0.0%)</span>'}) do
		t:assert(response.body:find('<td>' .. cell .. '</td>', 1, true), cell)
	end
	stack:close()
end

return test
