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
	stack.subscriptions:create("local", "openai_compat", 1, {
		base_url = "http://127.0.0.1:18020/v1", api_key = "PRIVATE-UPSTREAM-KEY", models = {"qwen"},
	}, {}, os.time())
	stack.models:create("lite", "qwen", "Simple alias", os.time())
	stack.server:reload(stack.subscriptions:list(), stack.models:list())
	local cookie = login(t, stack)
	local response = request(t, stack, "GET", "/admin/subscriptions", nil, cookie)
	t:eq(response.status, 200)
	t:assert(response.body:find("local", 1, true))
	t:assert(response.body:find("qwen", 1, true))
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
	for _, path in ipairs({"users", "subscriptions", "models", "usage", "status"}) do
		response = request(t, stack, "GET", "/admin/" .. path, nil, cookie)
		local _, forms = response.body:gsub("<form[%s>]", "")
		t:eq(forms, 1)
		t:assert(response.body:find('action="/admin/logout"', 1, true))
	end
	stack:close()
end

---@param t testing.T
function test.usage_and_status_pages_render(t)
	local stack = Stack()
	local cookie = login(t, stack)
	stack.usage_repo:record(os.time(), "alice", 200, "glm-5.3", "glm-5.3", "zai-1",
		{input_tokens = 10, output_tokens = 5, cached_input_tokens = 2, estimated = false})
	local response = request(t, stack, "GET", "/admin/usage?hours=168", nil, cookie)
	t:eq(response.status, 200)
	t:assert(response.body:find("By user", 1, true))
	t:assert(response.body:find("alice", 1, true))
	t:assert(response.body:find("0.0000", 1, true))
	response = request(t, stack, "GET", "/admin/status", nil, cookie)
	t:eq(response.status, 200)
	t:assert(response.body:find("Live subscription status", 1, true))
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
	stack.subscriptions:create("direct", "openai", 1, {auth_path = "unused", models = {"gpt"}}, {}, os.time())
	stack.server:reload(stack.subscriptions:list(), {})
	local cookie = login(t, stack)
	local response = request(t, stack, "GET", "/admin/subscriptions", nil, cookie)
	t:assert(response.body:find("logging_in", 1, true))
	t:eq(response.body:find("PRIVATE-CODE", 1, true), nil)
	t:eq(response.headers:get("Cache-Control"), "no-store")
	stack:close()
end

return test
