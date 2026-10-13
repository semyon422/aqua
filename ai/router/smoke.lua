-- Smoke test: boots the full router with a local mock upstream and exercises
-- MCP -> user -> subscription -> inference end to end. Run manually with
-- ./luajit aqua/ai/router/smoke.lua; not part of the ./test suite.
---@diagnostic disable: no-unknown, codestyle-check, unused-local
require("pkg_config")
local pkg = require("aqua.pkg")
pkg.export_lua()

local coext = require("coext")
local json = require("web.json")
local CosocketScheduler = require("web.luasocket.CosocketScheduler")
local CosocketServer = require("web.luasocket.CosocketServer")
local http_util = require("web.http.util")
local Server = require("ai.router.Server")
local AdminPages = require("ai.router.AdminPages")
local Management = require("ai.router.Management")
local McpTools = require("ai.router.McpTools")
local McpServer = require("mcp.Server")
local McpClient = require("mcp.Client")
local UsageMonitor = require("ai.router.UsageMonitor")
local UsageRepo = require("ai.router.UsageRepo")
local UsersRepo = require("ai.router.UsersRepo")
local SubscriptionsRepo = require("ai.router.SubscriptionsRepo")
local ModelsRepo = require("ai.router.ModelsRepo")
local CompatProvider = require("ai.router.CompatProvider")
local RouterDatabase = require("ai.router.storage.RouterDatabase")
local LjsqliteDatabase = require("rdb.db.LjsqliteDatabase")

local scheduler = CosocketScheduler()
local storage = RouterDatabase(LjsqliteDatabase())
storage.path = ":memory:"
storage:open()
local users = UsersRepo(storage.models)
local subscriptions = SubscriptionsRepo(storage.models)
local models = ModelsRepo(storage.models)
local usage_repo = UsageRepo(storage.models)
local monitor = UsageMonitor({usage_repo = usage_repo, logger = function() end})

-- Mock upstream: an OpenAI-compatible chat completions endpoint.
local upstream_requests = 0
local upstream_server = CosocketServer(scheduler, function(client)
	local buffer = ""
	while true do
		local chunk, err = client:receiveany(65536)
		if not chunk then break end
		buffer = buffer .. chunk
		if buffer:find("\r\n\r\n", 1, true) then break end
	end
	upstream_requests = upstream_requests + 1
		local body = json.encode({
		id = "up-1", object = "chat.completion", created = 1, model = "llama-70b",
		choices = {{index = 0, message = {role = "assistant", content = "mock reply"}, finish_reason = "stop"}},
		usage = {prompt_tokens = 9, completion_tokens = 4, total_tokens = 13},
	})
	client:send("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: " .. #body .. "\r\nConnection: close\r\n\r\n" .. body)
	client:close()
end, {})
assert(upstream_server:start("127.0.0.1", 0))
local _, upstream_port = upstream_server:getAddress()

local server = Server({
	scheduler = scheduler,
	users_repo = users,
	usage_repo = usage_repo,
	monitor = monitor,
	logger = function() end,
	provider_factory = function(subscription)
		if subscription.kind ~= "openai_compat" then return nil end
		local config = subscription.config
		---@cast config {[string]: any}
		return CompatProvider({
			config = config,
			request = function(url, body, options)
				options = options or {}
				options.scheduler = scheduler
				return http_util.request(url, body, options)
			end,
			open_stream = function() return nil, "not used" end,
			timeout = 5,
		})
	end,
})
local admin = AdminPages({
	users_repo = users,
	subscriptions_repo = subscriptions,
	models_repo = models,
	usage_repo = usage_repo,
	monitor = monitor,
	server = server,
	password = "admin-password-admin-password",
	get_time = os.time,
})
local management = Management({users_repo = users, subscriptions_repo = subscriptions, models_repo = models,
	usage_repo = usage_repo, monitor = monitor, server = server})
local mcp = McpServer(scheduler, McpTools.create(management), {port = 0, token = "smoke-management-token"})
assert(mcp:start())
server:reload(subscriptions:list(), models:list())
server.admin_handler = function(req, res) return admin:handle(req, res) end
assert(server:start("127.0.0.1", 0))
local _, router_port = server:getAddress()

local function request(method, path, form, cookie)
	local response, request_err
	local thread = coext.detach(coroutine.create(function()
		local headers = {}
		if cookie then headers.Cookie = cookie end
		local encoded
		if form then
			headers["Content-Type"] = "application/x-www-form-urlencoded"
			encoded = http_util.encode_query_string(form)
		end
		local result, err = http_util.request(("http://127.0.0.1:%d%s"):format(router_port, path), encoded,
			{method = method, headers = headers, scheduler = scheduler, timeout = 3})
		response = result
		request_err = err
	end))
	coroutine.resume(thread)
	while coroutine.status(thread) ~= "dead" do
		local ok, err = scheduler:update(0.01)
		if not ok and err then error(err) end
	end
	assert(request_err == nil, request_err)
	return response
end

-- Dashboard authentication remains available, but management uses MCP.
local r = request("POST", "/admin/login", {password = "admin-password-admin-password"})
assert(r.status == 303, "login failed: " .. r.status)
local cookie = r.headers:get("Set-Cookie"):match("(router_admin=[^;]+)")
r = request("GET", "/admin/users", nil, cookie)
local user_key
local mcp_thread = coext.detach(coroutine.create(function()
	local _, mcp_port = mcp:getAddress()
	local client = McpClient({url = ("http://127.0.0.1:%d/mcp"):format(mcp_port), token = "smoke-management-token", scheduler = scheduler})
	assert(client:initialize())
	assert(#assert(client:listTools()).tools == 17)
	local saved = assert(client:callTool("router_save_subscription", {
		name = "local-llama", kind = "openai_compat", priority = 1,
		config = {base_url = ("http://127.0.0.1:%d/v1"):format(upstream_port), models = {"llama-70b"}},
	}))
	assert(not saved.isError, saved.content[1].text)
	local created = assert(client:callTool("router_create_user", {name = "smoke-user", models = {"llama-70b"}}))
	assert(not created.isError, created.content[1].text)
	user_key = created.structuredContent.api_key
	client:close()
end))
coroutine.resume(mcp_thread)
while coroutine.status(mcp_thread) ~= "dead" do assert(scheduler:update(0.01)) end
assert(user_key, "no key in MCP response")
r = request("POST", "/admin/users", {name = "forbidden"}, cookie)
assert(r.status == 405, "dashboard must be read-only")

-- inference through the router with the fresh key
local inference_response, inference_err
local inference_thread = coext.detach(coroutine.create(function()
	local result, err = http_util.request(("http://127.0.0.1:%d/v1/chat/completions"):format(router_port),
		json.encode({model = "llama-70b", messages = {{role = "user", content = "hi"}}}),
		{method = "POST", headers = {Authorization = "Bearer " .. user_key, ["Content-Type"] = "application/json"}, scheduler = scheduler, timeout = 3})
	inference_response = result
	inference_err = err
end))
coroutine.resume(inference_thread)
while coroutine.status(inference_thread) ~= "dead" do
	local ok, err = scheduler:update(0.01)
	if not ok and err then error(err) end
end
assert(inference_err == nil, inference_err)
r = inference_response
assert(r.status == 200, "inference failed: " .. r.status .. " " .. r.body:sub(1, 200))
local completion = json.decode(r.body)
assert(completion.choices[1].message.content == "mock reply", "wrong content")
assert(completion.usage.prompt_tokens == 9, "wrong usage")
assert(upstream_requests == 1, "upstream not called")

-- models endpoint shows the granted model
local models_response, models_err
local models_thread = coext.detach(coroutine.create(function()
	local result, err = http_util.request(("http://127.0.0.1:%d/v1/models"):format(router_port), nil,
		{method = "GET", headers = {Authorization = "Bearer " .. user_key}, scheduler = scheduler, timeout = 3})
	models_response = result
	models_err = err
end))
coroutine.resume(models_thread)
while coroutine.status(models_thread) ~= "dead" do
	local ok, err = scheduler:update(0.01)
	if not ok and err then error(err) end
end
assert(models_err == nil, models_err)
r = models_response
assert(r.status == 200 and r.body:find("llama-70b", 1, true), "models missing")

-- usage was recorded
local history = usage_repo:history(os.time())
assert(history.rows[1] and history.rows[1].input_tokens == 9, "usage not recorded")

print("SMOKE OK: MCP -> user -> subscription -> inference -> usage; dashboard read-only")
print("upstream requests:", upstream_requests)
upstream_server:stop()
mcp:stop()
server:stop()
storage:close()
