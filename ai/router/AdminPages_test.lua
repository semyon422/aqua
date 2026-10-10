local coext = require("coext")
---@type {gettime: fun(): number}
local socket = require("socket")
local json = require("web.json")
local CosocketScheduler = require("web.luasocket.CosocketScheduler")
local http_util = require("web.http.util")
local Server = require("ai.router.Server")
local AdminPages = require("ai.router.AdminPages")
local UsageMonitor = require("ai.router.UsageMonitor")
local UsageRepo = require("ai.router.UsageRepo")
local UsersRepo = require("ai.router.UsersRepo")
local SubscriptionsRepo = require("ai.router.SubscriptionsRepo")
local ModelsRepo = require("ai.router.ModelsRepo")
local WindowsRepo = require("ai.router.WindowsRepo")
local RouterDatabase = require("ai.router.storage.RouterDatabase")
local LjsqliteDatabase = require("rdb.db.LjsqliteDatabase")

local test = {}

local ADMIN_PASSWORD = "admin-password-admin-password"

---@class test.AdminStack
---@field storage ai.router.RouterDatabase
---@field server ai.router.Server
---@field admin ai.router.AdminPages
---@field scheduler web.CosocketScheduler
---@field users ai.router.UsersRepo
---@field subscriptions ai.router.SubscriptionsRepo
---@field models ai.router.ModelsRepo
---@field usage_repo ai.router.UsageRepo

---@return test.AdminStack
local function startStack()
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
	local scheduler = CosocketScheduler()
	local server = Server({
		scheduler = scheduler,
		users_repo = users,
		usage_repo = usage_repo,
		monitor = monitor,
		logger = function() end,
		provider_factory = function() return nil end,
	})
	local admin = AdminPages({
		users_repo = users,
		subscriptions_repo = subscriptions,
		models_repo = models,
		usage_repo = usage_repo,
		monitor = monitor,
		server = server,
		password = ADMIN_PASSWORD,
	})
	admin:setReloadCallback(function()
		server:reload(subscriptions:list(), models:list())
	end)
	server:reload(subscriptions:list(), models:list())
	server.admin_handler = function(req, res)
		return admin:handle(req, res)
	end
	local stack = {
		storage = storage,
		server = server,
		admin = admin,
		scheduler = scheduler,
		users = users,
		subscriptions = subscriptions,
		models = models,
		usage_repo = usage_repo,
	}
	assert(server:start("127.0.0.1", 0))
	return stack
end

---@param t testing.T
---@param stack test.AdminStack
---@param thread thread
local function pump(t, stack, thread)
	local deadline = socket.gettime() + 2
	while coroutine.status(thread) ~= "dead" do
		local ok, err = stack.scheduler:update(0.01)
		if not ok and err then error(err) end
		t:assert(socket.gettime() < deadline)
	end
end

-- A POST form request; extra_headers carries the session cookie.
---@param t testing.T
---@param stack test.AdminStack
---@param method string
---@param path string
---@param form table?
---@param cookie string?
---@return {status: integer, body: string, headers: web.Headers}
local function request(t, stack, method, path, form, cookie)
	---@type {status: integer, body: string, headers: web.Headers}?
	local response
	---@type string?
	local request_err
	local thread = coext.detach(coroutine.create(function()
		local headers = {}
		if cookie then headers.Cookie = cookie end
		if form then headers["Content-Type"] = "application/x-www-form-urlencoded" end
		local _, port = stack.server:getAddress()
		local encoded = form and http_util.encode_query_string(form) or nil
		local result, err = http_util.request(
			("http://127.0.0.1:%d%s"):format(assert(port), path),
			encoded,
			{
				method = method,
				headers = headers,
				scheduler = stack.scheduler,
				timeout = 1,
			}
		)
		response = result and {status = result.status, body = result.body, headers = result.headers} or nil
		request_err = err
	end))
	coroutine.resume(thread)
	pump(t, stack, thread)
	t:eq(request_err, nil)
	return assert(response)
end

---@param t testing.T
---@param stack test.AdminStack
---@return string cookie
---@return string csrf_token
local function login(t, stack)
	local response = request(t, stack, "POST", "/admin/login", {password = ADMIN_PASSWORD})
	t:eq(response.status, 303)
	local set_cookie = response.headers:get("Set-Cookie")
	t:assert(set_cookie)
	local cookie = set_cookie:match("(router_admin=[^;]+)")
	t:assert(cookie)
	-- extract the csrf token by requesting a page
	response = request(t, stack, "GET", "/admin/users", nil, cookie)
	local csrf = response.body:match('name="csrf_token" value="([^"]+)"')
	t:assert(csrf)
	return cookie, csrf
end

---@param t testing.T
function test.login_flow_and_csrf(t)
	local stack = startStack()
	-- unauthenticated access redirects to login
	local response = request(t, stack, "GET", "/admin/users", nil, nil)
	t:eq(response.status, 303)
	t:eq(response.headers:get("Location"), "/admin")

	-- wrong password re-renders the login form with 401
	response = request(t, stack, "POST", "/admin/login", {password = "wrong-password-wrong"})
	t:eq(response.status, 401)
	t:assert(response.body:find("Invalid password", 1, true))

	local cookie, csrf = login(t, stack)

	-- mutation without CSRF is forbidden
	response = request(t, stack, "POST", "/admin/users/create", {
		name = "bob", models = "", csrf_token = "wrong",
	}, cookie)
	t:eq(response.status, 403)

	-- mutation with CSRF creates the user
	response = request(t, stack, "POST", "/admin/users/create", {
		name = "bob", models = "glm-5.3\ngpt-6-luna", csrf_token = csrf,
	}, cookie)
	t:eq(response.status, 200)
	t:assert(response.body:find("bob", 1, true))
	local new_key = response.body:match("New API key %(shown only once%): <code>([^<]+)</code>")
	t:assert(new_key and #new_key >= 32)

	-- the created user grants are persisted
	local user = stack.users:findByName("bob")
	t:assert(user)
	t:tdeq(stack.users:getGrants(user.id), {"glm-5.3", "gpt-6-luna"})
	stack.server:stop()
	stack.storage:close()
end

---@param t testing.T
function test.users_mutations(t)
	local stack = startStack()
	local cookie, csrf = login(t, stack)
	local form = {csrf_token = csrf}

	local create_response = request(t, stack, "POST", "/admin/users/create", {name = "carol", models = "lite", csrf_token = csrf}, cookie)
	t:eq(create_response.status, 200)
	local carol = stack.users:findByName("carol")
	t:assert(carol)

	-- disable
	form = {csrf_token = csrf, id = tostring(carol.id), disabled = "on"}
	request(t, stack, "POST", "/admin/users/update", form, cookie)
	t:eq(stack.users:get(carol.id).disabled, true)

	-- regenerate keeps the user but invalidates nothing visible here
	request(t, stack, "POST", "/admin/users/regenerate", {csrf_token = csrf, id = tostring(carol.id)}, cookie)

	-- delete removes grants too
	request(t, stack, "POST", "/admin/users/delete", {csrf_token = csrf, id = tostring(carol.id)}, cookie)
	t:eq(stack.users:get(carol.id), nil)
	t:tdeq(stack.users:getGrants(carol.id), {})

	-- validation error renders a 400 page without crashing
	local bad_form = {csrf_token = csrf, name = ""}
	local error_response = request(t, stack, "POST", "/admin/users/create", bad_form, cookie)
	t:eq(error_response.status, 400)
	t:assert(error_response.body:find("name is required", 1, true))
	stack.server:stop()
	stack.storage:close()
end

---@param t testing.T
function test.subscription_save_validates_catalog(t)
	local stack = startStack()
	local cookie, csrf = login(t, stack)

	-- a valid zai subscription is persisted and the router sees it
	request(t, stack, "POST", "/admin/subscriptions/save", {
		csrf_token = csrf,
		name = "zai-main",
		kind = "zai",
		priority = "1",
		enabled = "on",
		config = json.encode({
			base_url = "https://api.z.ai/api/coding/paas/v4",
			api_key = "key",
			models = {"glm-5.3"},
		}),
		limits = json.encode({five_hour_threshold = 80}),
	}, cookie)
	t:assert(stack.subscriptions:findByName("zai-main"))
	t:eq(stack.server.router.state.subscriptions[1].name, "zai-main")
	t:eq(stack.server.router.state.public_models["glm-5.3"], true)

	-- a model alias referencing a missing model is rejected before persisting
	request(t, stack, "POST", "/admin/models/save", {
		csrf_token = csrf,
		name = "bad",
		chain = "missing-model",
	}, cookie)
	t:eq(stack.models:findByName("bad"), nil)

	-- a valid alias is created and reloads the router
	request(t, stack, "POST", "/admin/models/save", {
		csrf_token = csrf,
		name = "lite",
		chain = "glm-5.3",
	}, cookie)
	t:assert(stack.models:findByName("lite"))
	t:eq(stack.server.router.state.alias_models["lite"][1], "glm-5.3")

	-- deleting the subscription breaks the alias: rejected without persisting
	request(t, stack, "POST", "/admin/subscriptions/delete", {
		csrf_token = csrf, id = tostring(stack.subscriptions:findByName("zai-main").id),
	}, cookie)
	t:assert(stack.subscriptions:findByName("zai-main"))
	stack.server:stop()
	stack.storage:close()
end

---@param t testing.T
function test.usage_and_status_pages_render(t)
	local stack = startStack()
	local cookie, csrf = login(t, stack)
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
	stack.server:stop()
	stack.storage:close()
end

return test
