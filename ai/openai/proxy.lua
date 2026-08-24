local coext = require("coext")
local HttpStream = require("web.http.HttpStream")
local http_util = require("web.http.util")
local CosocketScheduler = require("web.luasocket.CosocketScheduler")
local stbl = require("stbl")
local json = require("web.json")
local random = require("web.random")
local SubscriptionAuth = require("ai.openai.SubscriptionAuth")
local SubscriptionClient = require("ai.openai.SubscriptionClient")
local ProxyNetwork = require("ai.openai.ProxyNetwork")
local ProxyServer = require("ai.openai.ProxyServer")

---@class aqua.openai.ProxyConfig
---@field auth_path string?
---@field upstream_timeout number?
---@field tls_cafile string?
---@field network_path string?
---@field users aqua.openai.ProxyUser[]
---@field models string[]
---@field max_body_size integer?
---@field client_timeout number?
---@field max_clients integer?
---@field max_concurrent_requests_per_user integer?
---@field max_requests_per_minute integer?
---@field reasoning_effort aqua.openai.ReasoningEffort?
---@field verbosity "low"|"medium"|"high"?
---@field max_response_size integer?
---@field host string?
---@field port integer?

---@class aqua.openai.NetworkConfig
---@field socks5 aqua.openai.Socks5Config?

local command = "serve"
local config_path = arg[1] or "userdata/ai_proxy.lua"
if arg[1] == "login" or arg[1] == "--login" then
	command = "login"
	config_path = arg[2] or "userdata/ai_proxy.lua"
elseif arg[1] == "login-browser" or arg[1] == "--login-browser" then
	command = "login-browser"
	config_path = arg[2] or "userdata/ai_proxy.lua"
elseif arg[1] == "help" or arg[1] == "--help" or arg[1] == "-h" then
	print("Usage:")
	print("  ./luajit aqua/ai/openai/proxy.lua [config_path]")
	print("  ./luajit aqua/ai/openai/proxy.lua login [config_path]")
	print("  ./luajit aqua/ai/openai/proxy.lua login-browser [config_path]")
	return
end

local config_loader, config_err = loadfile(config_path)
assert(config_loader, ("failed to load proxy config %s: %s"):format(config_path, tostring(config_err)))
---@type aqua.openai.ProxyConfig
local config = config_loader()
assert(type(config) == "table", "proxy config must return a table")

local auth_path = config.auth_path or "userdata/ai_auth.lua"

---@return aqua.openai.SubscriptionCredentials
local function loadCredentials()
	---@type {[string]: any}
	local credentials = {}
	local file = io.open(auth_path, "rb")
	if file then
		file:close()
		local auth_loader, auth_err = loadfile(auth_path)
		assert(auth_loader, ("failed to load subscription auth %s: %s"):format(auth_path, tostring(auth_err)))
		---@type {[string]: any}
		local loaded_credentials = auth_loader()
		credentials = loaded_credentials
		assert(type(credentials) == "table", "subscription auth must return a table")
	end
	---@type {[string]: string|integer}
	local defaults = {access_token = "", refresh_token = "", expires_at = 0, account_id = ""}
	for key, default in pairs(defaults) do
		if credentials[key] == nil then credentials[key] = default end
		assert(type(credentials[key]) == type(default), "subscription auth " .. key .. " has an invalid type")
	end
	assert(credentials.expires_at >= 0 and credentials.expires_at % 1 == 0,
		"subscription auth expires_at must be a non-negative integer")
	return credentials --[[@as aqua.openai.SubscriptionCredentials]]
end

local credentials = loadCredentials()

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
---@type aqua.openai.NetworkConfig
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
	open_url = function(url)
		print("Open this URL in a browser to sign in with ChatGPT:")
		print(url)
		print("Waiting for the callback on http://localhost:1455/auth/callback")
		return true
	end,
	request = request,
})

---@param thread thread
local function runThread(thread)
	thread = coext.detach(thread)
	assert(coroutine.resume(thread))
	while coroutine.status(thread) ~= "dead" do
		local update_ok, update_err = scheduler:update(1)
		assert(update_ok ~= nil, update_err)
	end
end

if command == "login" then
	---@type boolean?
	local login_ok
	---@type string?
	local login_err
	runThread(coroutine.create(function()
		login_ok, login_err = auth:loginWithDeviceCode(function(device_code)
			print("Open this URL in a browser and sign in with ChatGPT:")
			print(device_code.verification_url)
			print("Enter this one-time code (expires in 15 minutes):")
			print(device_code.user_code)
			print("Continue only if you started this login from this proxy.")
		end)
	end))
	assert(login_ok, "OpenAI device login failed: " .. tostring(login_err))
	print("OpenAI subscription login complete; credentials saved to " .. auth_path)
	return
elseif command == "login-browser" then
	local login_ok, login_err = auth:startLogin()
	assert(login_ok, login_err)
	while auth.status == "logging_in" do
		local update_ok, update_err = scheduler:update(1)
		assert(update_ok ~= nil, update_err)
	end
	auth:unload()
	assert(auth.status == "authenticated", "OpenAI browser login failed: " .. tostring(auth.error))
	print("OpenAI subscription login complete; credentials saved to " .. auth_path)
	return
end

assert(auth:isAuthenticated(),
	"OpenAI subscription login is required; run ./luajit aqua/ai/openai/proxy.lua login " .. config_path)

local users = assert(config.users, "proxy users are required")
for _, user in ipairs(users) do
	assert(type(user.access_token) == "string" and #user.access_token >= 32,
		"proxy user access tokens must contain at least 32 characters")
	assert(user.access_token ~= "replace-with-a-long-random-token",
		"replace the default proxy user access token before starting the server")
end

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

local usage_url = "https://chatgpt.com/backend-api/codex/usage"

---@return table?
---@return string?
---@return aqua.openai.ProviderError?
local function fetchUsage()
	local access_token, account_id, access_err = shared_auth.getAccess()
	if not access_token then return nil, access_err or "OpenAI login is required" end
	if not account_id or account_id == "" then return nil, "OpenAI login has no account ID" end
	local client_request_id = random.hex(16)
	local response, request_err = request(usage_url, nil, {
		method = "GET",
		headers = {
			Authorization = "Bearer " .. access_token,
			["ChatGPT-Account-Id"] = account_id,
			Accept = "application/json",
			Originator = "openai-proxy",
			["User-Agent"] = "openai-proxy",
			["x-client-request-id"] = client_request_id,
		},
	})
	if not response then return nil, request_err or "OpenAI usage request failed" end
	if response.status < 200 or response.status >= 300 then
		local request_id = response.headers and response.headers:get("x-request-id") or client_request_id
		return nil, "OpenAI usage request failed", {
			status = response.status,
			message = "OpenAI usage request failed",
			type = "upstream_error",
			code = "upstream_error",
			request_id = request_id,
		}
	end
	local usage, decode_err = json.decode_safe(response.body)
	if type(usage) ~= "table" then return nil, "invalid OpenAI usage response: " .. tostring(decode_err) end
	return usage
end

local server = ProxyServer({
	scheduler = scheduler,
	users = users,
	models = assert(config.models, "proxy models are required"),
	max_body_size = config.max_body_size,
	client_timeout = config.client_timeout,
	max_clients = config.max_clients,
	max_concurrent_requests_per_user = config.max_concurrent_requests_per_user,
	max_requests_per_minute = config.max_requests_per_minute,
	fetch_usage = fetchUsage,
	create_client = function(model, reasoning_effort, request_options)
		---@type aqua.openai.ProxyRequestOptions
		local client_options = request_options
		return SubscriptionClient({
			auth = shared_auth --[[@as aqua.openai.SubscriptionAuth]],
			model = model,
			reasoning_effort = reasoning_effort or config.reasoning_effort or "medium",
			prompt_cache_key = client_options.prompt_cache_key,
			prompt_cache_options = client_options.prompt_cache_options,
			tool_choice = client_options.tool_choice,
			parallel_tool_calls = client_options.parallel_tool_calls,
			verbosity = client_options.verbosity or config.verbosity or "low",
			text_format = client_options.text_format,
			max_response_size = config.max_response_size,
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
print(("OpenAI usage dashboard available at http://%s:%d/usage"):format(bound_host, bound_port))
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
