local coext = require("coext")
local socket = require("socket")
local http_util = require("web.http.util")
local Stack = require("ai.router.testing.Stack")
local OpenAILoginManager = require("ai.router.OpenAILoginManager")

local test = {}

---@param t testing.T
---@param stack ai.router.testing.Stack
---@param method string
---@param path string
---@param form table?
---@param cookie string?
---@return web.HttpResponse
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
	function manager:getState(auth_path)
		t:eq(auth_path, "unused")
		return {status = "logging_in", user_code = "PRIVATE-CODE", verification_url = "https://auth.openai.com/codex/device"}
	end
	stack.admin.openai_login = manager
	stack.channels:create("direct", "openai", {auth_path = "unused", models = {"gpt"}}, {}, os.time())
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
	t:assert(response.body:find("&lt;script&gt;private&lt;/script&gt;", 1, true))
	t:eq(response.body:find("<script>", 1, true), nil)
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

return test
