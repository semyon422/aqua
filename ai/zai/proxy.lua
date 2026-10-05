local HttpStream = require("web.http.HttpStream")
local http_util = require("web.http.util")
local json = require("web.json")
local CosocketScheduler = require("web.luasocket.CosocketScheduler")
local ProxyNetwork = require("ai.openai.ProxyNetwork")
local Client = require("ai.zai.Client")
local ProxyServer = require("ai.zai.ProxyServer")

---@class zai.ProxyConfig
---@field base_url string?
---@field api_key string
---@field usage_url string?
---@field network_path string?
---@field tls_cafile string?
---@field users zai.ProxyUser[]
---@field models string[]
---@field model_redirects {[string]: string}?
---@field thinking "enabled"|"disabled"?
---@field tool_stream boolean?
---@field upstream_timeout number?
---@field client_timeout number?
---@field max_body_size integer?
---@field max_clients integer?
---@field max_concurrent_requests_per_user integer?
---@field max_requests_per_minute integer?
---@field host string?
---@field port integer?

---@class zai.NetworkConfig
---@field socks5 openai.Socks5Config?

if arg[1] == "help" or arg[1] == "--help" or arg[1] == "-h" then
	print("Usage:")
	print("  ./luajit aqua/ai/zai/proxy.lua [config_path]")
	return
end

local config_path = arg[1] or "userdata/zai_proxy.lua"
local config_loader, config_err = loadfile(config_path)
assert(config_loader, ("failed to load proxy config %s: %s"):format(config_path, tostring(config_err)))
---@type zai.ProxyConfig
local config = config_loader()
assert(type(config) == "table", "proxy config must return a table")

assert(type(config.api_key) == "string" and #config.api_key >= 32,
	"proxy api_key must contain at least 32 characters")
assert(config.api_key ~= "replace-with-your-glm-coding-plan-api-key",
	"replace the default GLM API key before starting the server")

local users = assert(config.users, "proxy users are required")
for _, user in ipairs(users) do
	assert(type(user.access_token) == "string" and #user.access_token >= 32,
		"proxy user access tokens must contain at least 32 characters")
	assert(user.access_token ~= "replace-with-a-long-random-token",
		"replace the default proxy user access token before starting the server")
end

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
---@type zai.NetworkConfig
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

local base_url = config.base_url or "https://api.z.ai/api/coding/paas/v4"
local usage_url = config.usage_url or "https://api.z.ai/api/monitor/usage/quota/limit"

---@return table? usage
---@return string? request_error
---@return zai.ProviderError? provider_error
local function fetchUsage()
	local response, request_err = request(usage_url, nil, {
		method = "GET",
		headers = {
			Accept = "application/json",
			Authorization = "Bearer " .. config.api_key,
		},
	})
	if not response then return nil, request_err or "Z.ai usage request failed" end
	if response.status < 200 or response.status >= 300 then
		return nil, "Z.ai usage request failed", {
			status = 502,
			message = "Z.ai usage request failed",
			type = "upstream_error",
			code = "upstream_error",
		}
	end
	local usage, decode_err = json.decode_safe(response.body)
	if type(usage) ~= "table" then return nil, "invalid Z.ai usage response: " .. tostring(decode_err) end
	local data = usage.data
	if type(data) ~= "table" then return nil, "invalid Z.ai usage response: data object is missing" end
	return data
end

local server = ProxyServer({
	scheduler = scheduler,
	users = users,
	models = assert(config.models, "proxy models are required"),
	model_redirects = config.model_redirects,
	thinking = config.thinking,
	tool_stream = config.tool_stream,
	fetch_usage = fetchUsage,
	create_client = function()
		return Client({
			base_url = base_url,
			api_key = config.api_key,
			timeout = upstream_timeout,
			request = request,
			open_stream = openStream,
		})
	end,
	max_body_size = config.max_body_size,
	client_timeout = config.client_timeout,
	max_clients = config.max_clients,
	max_concurrent_requests_per_user = config.max_concurrent_requests_per_user,
	max_requests_per_minute = config.max_requests_per_minute,
})

local host = config.host or "127.0.0.1"
local port = config.port or 28082
local ok, start_err = server:start(host, port)
assert(ok, "failed to start Z.ai proxy: " .. tostring(start_err))
local bound_host, bound_port = server:getAddress()
print(("Z.ai proxy listening on http://%s:%d/v1"):format(assert(bound_host), assert(bound_port)))
print("Upstream: " .. base_url)
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
