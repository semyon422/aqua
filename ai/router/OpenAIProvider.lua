local class = require("class")
local stbl = require("stbl")
local json = require("web.json")
local random = require("web.random")
local SubscriptionAuth = require("ai.openai.SubscriptionAuth")
local SubscriptionAuthGuard = require("ai.openai.SubscriptionAuthGuard")
local SubscriptionClient = require("ai.openai.SubscriptionClient")

---@class ai.router.OpenAIProviderConfig
---@field auth_path string
---@field reasoning_effort openai.ReasoningEffort?
---@field verbosity "low"|"medium"|"high"?
---@field max_response_size integer?

---@class ai.router.OpenAIProviderOptions
---@field config ai.router.OpenAIProviderConfig
---@field scheduler web.CosocketScheduler
---@field request zai.RequestFunc
---@field open_stream openai.OpenStreamFunc
---@field timeout number?
---@field get_time (fun(): number)?
---@field auth openai.SubscriptionAuthGuard? injected in tests; built from auth_path otherwise
---@field usage_url string?

-- Upstream adapter for one ChatGPT channel: per-channel OAuth
-- credentials, native Responses transport, and the
-- Codex usage monitor fetch.
---@class ai.router.OpenAIProvider
---@operator call: ai.router.OpenAIProvider
---@field config ai.router.OpenAIProviderConfig
---@field auth openai.SubscriptionAuthGuard
---@field scheduler web.CosocketScheduler
---@field request zai.RequestFunc
---@field open_stream openai.OpenStreamFunc
---@field timeout number?
---@field get_time fun(): number
---@field usage_url string
local OpenAIProvider = class()

OpenAIProvider.usage_url = "https://chatgpt.com/backend-api/codex/usage"

---@param auth_path string
---@return openai.SubscriptionCredentials
local function loadCredentialsFile(auth_path)
	---@type {[string]: any}
	local credentials = {}
	local file = io.open(auth_path, "rb")
	if file then
		file:close()
		local loader, load_err = loadfile(auth_path)
		assert(loader, ("failed to load channel auth %s: %s"):format(auth_path, tostring(load_err)))
		---@type {[string]: any}
		local loaded = loader()
		credentials = loaded
		assert(type(credentials) == "table", "channel auth must return a table")
	end
	---@type {[string]: string|integer}
	local defaults = {access_token = "", refresh_token = "", expires_at = 0, account_id = ""}
	for key, default in pairs(defaults) do
		if credentials[key] == nil then credentials[key] = default end
		assert(type(credentials[key]) == type(default), "channel auth " .. key .. " has an invalid type")
	end
	assert(credentials.expires_at >= 0 and credentials.expires_at % 1 == 0,
		"channel auth expires_at must be a non-negative integer")
	return credentials --[[@as openai.SubscriptionCredentials]]
end

---@param auth_path string
---@param credentials openai.SubscriptionCredentials
local function saveCredentialsFile(auth_path, credentials)
	local tmp_path = auth_path .. ".tmp"
	local file = io.open(tmp_path, "w")
	assert(file, "failed to open " .. tmp_path .. " for writing")
	local ok, write_err = file:write(("return %s\n"):format(stbl.encode_pretty(credentials)))
	local close_ok, close_err = file:close()
	assert(ok and close_ok, write_err or close_err)
	assert(os.rename(tmp_path, auth_path), "failed to replace " .. auth_path)
end

---@param options ai.router.OpenAIProviderOptions
---@return openai.SubscriptionAuth
function OpenAIProvider.createAuth(options)
	local credentials = loadCredentialsFile(options.config.auth_path)
	return SubscriptionAuth({
		scheduler = options.scheduler,
		credentials = credentials,
		save_credentials = function()
			saveCredentialsFile(options.config.auth_path, credentials)
		end,
		open_url = function() return true end,
		request = options.request,
	})
end

---@param options ai.router.OpenAIProviderOptions
function OpenAIProvider:new(options)
	local config = options.config
	assert(type(config.auth_path) == "string" and config.auth_path ~= "", "openai auth_path is required")
	self.config = config
	self.scheduler = options.scheduler
	self.request = options.request
	self.open_stream = options.open_stream
	self.timeout = options.timeout
	self.get_time = options.get_time or os.time
	self.usage_url = options.usage_url or OpenAIProvider.usage_url
	if options.auth then
		self.auth = options.auth
	else
		local auth = OpenAIProvider.createAuth(options)
		self.auth = SubscriptionAuthGuard(auth, options.scheduler)
	end
end

-- Creates a per-request client so concurrent requests never share response
-- assembly or cancellation state; authentication stays shared and guarded.
---@param upstream_model string
---@param session_id string?
---@return openai.SubscriptionClient
function OpenAIProvider:createClient(upstream_model, session_id)
	return SubscriptionClient({
		auth = self.auth,
		model = upstream_model,
		reasoning_effort = self.config.reasoning_effort or "medium",
		session_id = session_id,
		verbosity = self.config.verbosity,
		max_response_size = self.config.max_response_size,
		timeout = self.timeout,
		get_time = self.get_time,
		open_stream = self.open_stream,
	})
end

-- The server validates native input and affinity before any upstream work.
---@param body {[string]: any}
---@param upstream_model string
---@param session_id string?
---@param on_event (fun(event: table): boolean?)?
---@return table? response
---@return string? err
---@return zai.ProviderError? provider_error
function OpenAIProvider:createResponse(body, upstream_model, session_id, on_event)
	return self:createClient(upstream_model, session_id):createResponse(body, on_event)
end

-- Fetches the upstream Codex usage object (rate limit windows). Returns the
-- raw upstream object; window parsing lives with the usage monitor.
---@return table? usage
---@return string? request_error
---@return zai.ProviderError? provider_error
function OpenAIProvider:fetchUsage()
	local access_token, account_id, access_err = self.auth:getAccess()
	if not access_token then return nil, access_err or "OpenAI login is required" end
	if not account_id or account_id == "" then return nil, "OpenAI login has no account ID" end
	local client_request_id = random.hex(16)
	local response, request_err = self.request(self.usage_url, nil, {
		method = "GET",
		headers = {
			Authorization = "Bearer " .. access_token,
			["ChatGPT-Account-Id"] = account_id,
			Accept = "application/json",
			Originator = "ai-router",
			["User-Agent"] = "ai-router",
			["x-client-request-id"] = client_request_id,
		},
	})
	if not response then return nil, request_err or "OpenAI usage request failed" end
	if response.status < 200 or response.status >= 300 then
		local request_id = response.headers and response.headers:get("x-request-id") or client_request_id
		return nil, "OpenAI usage request failed", {
			status = 502,
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

return OpenAIProvider
