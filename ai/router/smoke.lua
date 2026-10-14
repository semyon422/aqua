-- Smoke test: boots the full router with a local mock upstream and exercises
-- MCP -> user -> channel -> inference end to end. Run manually with
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
local ChannelsRepo = require("ai.router.ChannelsRepo")
local ModelsRepo = require("ai.router.ModelsRepo")
local CompatProvider = require("ai.router.CompatProvider")
local OpenAIProvider = require("ai.router.OpenAIProvider")
local HttpStream = require("web.http.HttpStream")
local RouterDatabase = require("ai.router.storage.RouterDatabase")
local LjsqliteDatabase = require("rdb.db.LjsqliteDatabase")

local scheduler = CosocketScheduler()
local storage = RouterDatabase(LjsqliteDatabase())
storage.path = ":memory:"
storage:open()
local users = UsersRepo(storage.models)
local channels = ChannelsRepo(storage.models)
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
	local content_type = "application/json"
	if buffer:find("POST /v1/responses ", 1, true) then
		content_type = "text/event-stream"
		local result = {id = "resp_mock", object = "response", status = "completed", model = "gpt-native",
			output = {{type = "reasoning", encrypted_content = "opaque"},
				{type = "function_call", id = "fc_1", call_id = "call_1", name = "inspect", arguments = "{}"}},
			usage = {input_tokens = 12, output_tokens = 4, input_tokens_details = {cached_tokens = 8}}}
		body = "data: " .. json.encode({type = "response.created", response = {id = "resp_mock", model = "gpt-native"}})
			.. "\n\ndata: " .. json.encode({type = "response.completed", response = result}) .. "\n\n"
	end
	client:send("HTTP/1.1 200 OK\r\nContent-Type: " .. content_type .. "\r\nContent-Length: " .. #body .. "\r\nConnection: close\r\n\r\n" .. body)
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
	provider_factory = function(channel)
		if channel.kind == "openai" then
			return OpenAIProvider({config = channel.config,
				auth = {getAccess = function() return "mock-access", "mock-account" end},
				request = function() return nil, "usage not used" end,
				open_stream = function(_, options)
					options.scheduler = scheduler
					local stream = HttpStream(options)
					local ok, err = stream:connect(("http://127.0.0.1:%d/v1/responses"):format(upstream_port))
					if not ok then stream:close() return nil, err end
					return stream
				end, timeout = 5})
		end
		if channel.kind ~= "openai_compat" then return nil end
		local config = channel.config
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
	channels_repo = channels,
	models_repo = models,
	usage_repo = usage_repo,
	monitor = monitor,
	server = server,
	password = "admin-password-admin-password",
	get_time = os.time,
})
local management = Management({users_repo = users, channels_repo = channels, models_repo = models,
	usage_repo = usage_repo, monitor = monitor, server = server})
local mcp = McpServer(scheduler, McpTools.create(management), {port = 0, token = "smoke-management-token"})
assert(mcp:start())
server:reload(channels:list(), models:list())
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
	local saved = assert(client:callTool("router_save_channel", {
		name = "local-llama", kind = "openai_compat",
		config = {base_url = ("http://127.0.0.1:%d/v1"):format(upstream_port), models = {"llama-70b"}},
	}))
	assert(not saved.isError, saved.content[1].text)
	local native = assert(client:callTool("router_save_channel", {
		name = "native-openai", kind = "openai", config = {models = {"gpt-native"}},
	}))
	assert(not native.isError, native.content[1].text)
	local created = assert(client:callTool("router_create_user", {name = "smoke-user", models = {"local-llama/llama-70b", "native-openai/gpt-native"}}))
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
		json.encode({model = "local-llama/llama-70b", messages = {{role = "user", content = "hi"}}}),
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

local native_thread = coext.detach(coroutine.create(function()
	for _, streaming in ipairs({false, true}) do
		local response = assert(http_util.request(("http://127.0.0.1:%d/v1/responses"):format(router_port),
			json.encode({model = "native-openai/gpt-native", input = "hi", stream = streaming, prompt_cache_key = "thread"}),
			{method = "POST", headers = {Authorization = "Bearer " .. user_key}, scheduler = scheduler, timeout = 3}))
		assert(response.status == 200, "native inference failed")
		if streaming then
			assert(response.body:find("event: response.completed", 1, true))
			assert(not response.body:find("[DONE]", 1, true))
		else
			local result = json.decode(response.body)
			assert(result.output[1].encrypted_content == "opaque")
			assert(result.output[2].call_id == "call_1")
			assert(result.usage.input_tokens_details.cached_tokens == 8)
		end
	end
end))
assert(coroutine.resume(native_thread))
while coroutine.status(native_thread) ~= "dead" do
	local ok, err = scheduler:update(0.01)
	assert(ok ~= nil, err)
end
local found_native = false
for _, row in ipairs(usage_repo:history(os.time()).rows) do
	if row.channel == "native-openai" then
		assert(row.requests == 2 and row.input_tokens == 24 and row.cached_input_tokens == 16)
		found_native = true
	end
end
assert(found_native and upstream_requests == 3, "native usage missing")

print("SMOKE OK: MCP -> user -> channels -> native Responses/Chat Completions -> usage; dashboard read-only")
print("upstream requests:", upstream_requests)
upstream_server:stop()
mcp:stop()
server:stop()
storage:close()
