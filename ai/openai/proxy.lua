local HttpStream = require("web.http.HttpStream")
local http_util = require("web.http.util")
local CosocketScheduler = require("web.luasocket.CosocketScheduler")
local stbl = require("stbl")
local SubscriptionAuth = require("ai.openai.SubscriptionAuth")
local SubscriptionClient = require("ai.openai.SubscriptionClient")
local ProxyNetwork = require("ai.openai.ProxyNetwork")
local ProxyServer = require("ai.openai.ProxyServer")

local config_path = arg[1] or "userdata/ai_proxy.lua"
local config_loader, config_err = loadfile(config_path)
assert(config_loader, ("failed to load proxy config %s: %s"):format(config_path, tostring(config_err)))
local config = config_loader()
assert(type(config) == "table", "proxy config must return a table")

local auth_path = config.auth_path or "userdata/ai_auth.lua"
local auth_loader, auth_err = loadfile(auth_path)
assert(auth_loader, ("failed to load subscription auth %s: %s"):format(auth_path, tostring(auth_err)))
local credentials = auth_loader()
assert(type(credentials) == "table", "subscription auth must return a table")

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
local network_loader, network_err = loadfile(network_path)
assert(network_loader, ("failed to load network config %s: %s"):format(network_path, tostring(network_err)))
local network_config = network_loader()
assert(type(network_config) == "table", "network config must return a table")
local network = ProxyNetwork({
	scheduler = scheduler,
	timeout = upstream_timeout,
	ssl_params = ssl_params,
	socks5 = network_config.socks5,
})

---@param url string
---@param options web.HttpClientOptions?
---@return web.HttpClientOptions
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

local function saveCredentials()
	local temporary_path = auth_path .. ".tmp"
	local file, err = io.open(temporary_path, "wb")
	assert(file, err)
	local ok
	ok, err = file:write(("return %s\n"):format(stbl.encode_pretty(credentials)))
	local close_ok, close_err = file:close()
	assert(ok and close_ok, err or close_err)
	assert(os.rename(temporary_path, auth_path))
end

local auth = SubscriptionAuth({
	scheduler = scheduler,
	credentials = credentials,
	save_credentials = saveCredentials,
	open_url = function() return false end,
	request = request,
})

local auth_busy = false
local shared_auth = {
	getAccess = function()
		while auth_busy do scheduler:sleep(0.01) end
		auth_busy = true
		local access_token, account_id, access_err = auth:getAccess()
		auth_busy = false
		return access_token, account_id, access_err
	end,
}

local server = ProxyServer({
	scheduler = scheduler,
	users = assert(config.users, "proxy users are required"),
	models = assert(config.models, "proxy models are required"),
	max_body_size = config.max_body_size,
	client_timeout = config.client_timeout,
	create_client = function(model, reasoning_effort)
		return SubscriptionClient({
			auth = shared_auth --[[@as aqua.openai.SubscriptionAuth]],
			model = model,
			reasoning_effort = reasoning_effort or config.reasoning_effort or "medium",
			timeout = upstream_timeout,
			open_stream = openStream,
		})
	end,
})

local host = config.host or "127.0.0.1"
local port = config.port or 28081
local ok, start_err = server:start(host, port)
assert(ok, "failed to start OpenAI subscription proxy: " .. tostring(start_err))
local bound_host, bound_port = server:getAddress()
print(("OpenAI subscription proxy listening on http://%s:%d/v1"):format(assert(bound_host), assert(bound_port)))
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
if not running and not tostring(run_err):find("interrupted!", 1, true) then
	error(run_err, 0)
end
