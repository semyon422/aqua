local coext = require("coext")
local CosocketScheduler = require("web.luasocket.CosocketScheduler")
local HttpStream = require("web.http.HttpStream")
local http_util = require("web.http.util")
local ProxyNetwork = require("ai.openai.ProxyNetwork")
local OpenAIProvider = require("ai.router.OpenAIProvider")
local ZaiProvider = require("ai.router.ZaiProvider")
local CompatProvider = require("ai.router.CompatProvider")
local Server = require("ai.router.Server")
local AdminPages = require("ai.router.AdminPages")
local UsersRepo = require("ai.router.UsersRepo")
local SubscriptionsRepo = require("ai.router.SubscriptionsRepo")
local ModelsRepo = require("ai.router.ModelsRepo")
local WindowsRepo = require("ai.router.WindowsRepo")
local UsageRepo = require("ai.router.UsageRepo")
local UsageMonitor = require("ai.router.UsageMonitor")
local RouterDatabase = require("ai.router.storage.RouterDatabase")
local LjsqliteDatabase = require("rdb.db.LjsqliteDatabase")

---@class ai.router.NetworkConfig
---@field socks5 openai.Socks5Config?

---@class ai.router.Config
---@field host string?
---@field port integer?
---@field admin_password string
---@field db_path string?
---@field network_path string?
---@field tls_cafile string?
---@field model_prices {[string]: ai.router.ModelPrice}?
---@field upstream_timeout number?
---@field client_timeout number?
---@field max_body_size integer?
---@field max_clients integer?
---@field max_concurrent_requests_per_user integer?
---@field max_requests_per_minute integer?
---@field cooldown_seconds number?
---@field staleness number?
---@field usage_poll_interval integer?

if arg[1] == "help" or arg[1] == "--help" or arg[1] == "-h" then
	print("Usage:")
	print("  ./luajit aqua/ai/router/proxy.lua [config_path]")
	return
end

local config_path = arg[1] or "userdata/ai_router.lua"
local config_loader, config_err = loadfile(config_path)
assert(config_loader, ("failed to load router config %s: %s"):format(config_path, tostring(config_err)))
---@type ai.router.Config
local config = config_loader()
assert(type(config) == "table", "router config must return a table")
assert(type(config.admin_password) == "string" and #config.admin_password >= 16,
	"admin_password must contain at least 16 characters")

local scheduler = CosocketScheduler()
local upstream_timeout = config.upstream_timeout or 300
local ssl_params = {
	mode = "client",
	protocol = "any",
	options = {"all", "no_sslv2", "no_sslv3", "no_tlsv1"},
	verify = "peer",
	cafile = config.tls_cafile or "resources/certs/cacert.pem",
}

local network_path = config.network_path or "userdata/network.lua"
local network_loader, network_load_err = loadfile(network_path)
assert(network_loader, ("failed to load network config %s: %s"):format(network_path, tostring(network_load_err)))
---@type ai.router.NetworkConfig
local network_config = network_loader()
assert(type(network_config) == "table", "network config must return a table")
local network = ProxyNetwork({
	scheduler = scheduler,
	timeout = upstream_timeout,
	ssl_params = ssl_params,
	socks5 = network_config.socks5,
})

local function withNetworkOptions(url, options)
	return network:getOptions(url, options)
end

local function request(url, body, options)
	return http_util.request(url, body, withNetworkOptions(url, options))
end

local function openStream(url, options)
	local stream = HttpStream(withNetworkOptions(url, options))
	local ok, err = stream:connect(url)
	if not ok then
		stream:close()
		return nil, err
	end
	return stream
end

local storage = RouterDatabase(LjsqliteDatabase())
if config.db_path then storage.path = config.db_path end
storage:open()

local users_repo = UsersRepo(storage.models)
local subscriptions_repo = SubscriptionsRepo(storage.models)
local models_repo = ModelsRepo(storage.models)
local usage_repo = UsageRepo(storage.models, config.model_prices)
local windows_repo = WindowsRepo(storage.models)

local monitor = UsageMonitor({
	usage_repo = usage_repo,
	windows_repo = windows_repo,
	logger = print,
	default_interval = config.usage_poll_interval,
})

-- Builds the provider for one subscription row. OpenAI subscriptions load
-- their OAuth credentials from the ignored auth file in their config; the
-- file is read when the provider is constructed, so a missing file fails the
-- startup instead of the first request.
---@param subscription ai.router.SubscriptionRow
---@return ai.router.ProviderMethods?
local function providerFactory(subscription)
	local subscription_config = subscription.config
	---@cast subscription_config {[string]: any}
	if subscription.kind == "openai" then
		return OpenAIProvider({
			config = {
				auth_path = assert(subscription_config.auth_path),
				reasoning_effort = subscription_config.reasoning_effort,
				verbosity = subscription_config.verbosity,
				max_response_size = subscription_config.max_response_size,
			},
			scheduler = scheduler,
			request = request,
			open_stream = openStream,
			timeout = upstream_timeout,
		})
	elseif subscription.kind == "zai" then
		return ZaiProvider({
			config = subscription_config,
			request = request,
			open_stream = openStream,
			timeout = upstream_timeout,
		})
	elseif subscription.kind == "openai_compat" then
		return CompatProvider({
			config = subscription_config,
			request = request,
			open_stream = openStream,
			timeout = upstream_timeout,
		})
	end
	return nil
end

local server = Server({
	scheduler = scheduler,
	users_repo = users_repo,
	usage_repo = usage_repo,
	monitor = monitor,
	provider_factory = providerFactory,
	staleness = config.staleness,
	logger = print,
	client_timeout = config.client_timeout,
	max_body_size = config.max_body_size,
	max_clients = config.max_clients,
	max_concurrent_requests_per_user = config.max_concurrent_requests_per_user,
	max_requests_per_minute = config.max_requests_per_minute,
	cooldown_seconds = config.cooldown_seconds,
})

local admin = AdminPages({
	users_repo = users_repo,
	subscriptions_repo = subscriptions_repo,
	models_repo = models_repo,
	usage_repo = usage_repo,
	monitor = monitor,
	server = server,
	password = assert(config.admin_password),
})
admin:setReloadCallback(function()
	server:reload(subscriptions_repo:list(), models_repo:list())
end)
server.admin_handler = function(req, res)
	return admin:handle(req, res)
end

server:reload(subscriptions_repo:list(), models_repo:list())

-- Background usage polling.
coext.detach(coroutine.create(function()
	while true do
		monitor:update(os.time())
		scheduler:sleep(5)
	end
end))

local host = config.host or "127.0.0.1"
local port = config.port or 28083
local ok, start_err = server:start(host, port)
assert(ok, "failed to start AI router: " .. tostring(start_err))
local bound_host, bound_port = server:getAddress()
print(("AI router listening on http://%s:%d"):format(assert(bound_host), assert(bound_port)))
print(("Admin panel: http://%s:%d/admin"):format(bound_host, bound_port))
print(("Inference endpoint: http://%s:%d/v1/chat/completions"):format(bound_host, bound_port))
if network.socks5 then
	print(("SOCKS5 upstream routing enabled via %s:%d"):format(network.socks5.host, network.socks5.port))
end

local running, run_err = pcall(function()
	while true do
		local update_ok, update_err = scheduler:update(1)
		assert(update_ok ~= nil, update_err)
	end
end)
server:stop()
storage:close()
if not running and not tostring(run_err):find("interrupted!", 1, true) then
	error(run_err, 0)
end
