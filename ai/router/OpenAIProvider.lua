local class = require("class")
local stbl = require("stbl")
local json = require("web.json")
local random = require("web.random")
local SubscriptionAuth = require("ai.openai.SubscriptionAuth")
local SubscriptionAuthGuard = require("ai.openai.SubscriptionAuthGuard")
local SubscriptionClient = require("ai.openai.SubscriptionClient")
local ChatCompat = require("ai.openai.ChatCompat")
local Provider = require("ai.router.Provider")

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

-- Upstream adapter for one ChatGPT subscription: per-subscription OAuth
-- credentials, request translation through ai.openai.ChatCompat, and the
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
		assert(loader, ("failed to load subscription auth %s: %s"):format(auth_path, tostring(load_err)))
		---@type {[string]: any}
		local loaded = loader()
		credentials = loaded
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
		local auth = SubscriptionAuth({
			scheduler = options.scheduler,
			credentials = loadCredentialsFile(config.auth_path),
			save_credentials = function(credentials)
				saveCredentialsFile(config.auth_path, credentials)
			end,
			open_url = function(url)
				print("Open this URL in a browser to sign in with ChatGPT:")
				print(url)
				return true
			end,
			request = options.request,
		})
		self.auth = SubscriptionAuthGuard(auth, options.scheduler)
	end
end

-- Creates a per-request client so concurrent requests never share response
-- assembly or cancellation state; authentication stays shared and guarded.
---@param upstream_model string
---@param compat openai.ChatCompatRequest
---@return openai.SubscriptionClient
function OpenAIProvider:createClient(upstream_model, compat)
	return SubscriptionClient({
		auth = self.auth,
		model = upstream_model,
		reasoning_effort = compat.reasoning_effort or self.config.reasoning_effort or "medium",
		prompt_cache_key = compat.client_options.prompt_cache_key,
		prompt_cache_options = compat.client_options.prompt_cache_options,
		tool_choice = compat.client_options.tool_choice,
		parallel_tool_calls = compat.client_options.parallel_tool_calls,
		verbosity = compat.client_options.verbosity or self.config.verbosity,
		text_format = compat.client_options.text_format,
		max_response_size = self.config.max_response_size,
		timeout = self.timeout,
		get_time = self.get_time,
		open_stream = self.open_stream,
	})
end

-- Runs a validated completion. `on_delta` presence selects streaming; deltas
-- are translated to Chat Completions shapes before relaying.
---@param body table
---@param upstream_model string
---@param on_delta (fun(delta: table): boolean?)?
---@return ai.router.CanonicalMessage? message
---@return string? err
---@return zai.ProviderError? provider_error
function OpenAIProvider:complete(body, upstream_model, on_delta)
	local compat, message, code = ChatCompat.normalizeRequest(body)
	if not compat then
		return nil, nil, {status = 400, message = message, type = "invalid_request_error", code = code}
	end
	local client = self:createClient(upstream_model, compat)
	---@type openai.Message?
	local result
	---@type string?
	local err
	---@type openai.ProviderError?
	local provider_error
	if on_delta then
		result, err, provider_error = client:completeStream(compat.messages, compat.tools,
			function(content)
				return on_delta({content = content})
			end,
			function(content)
				return on_delta({reasoning_content = content})
			end,
			function(delta)
				return on_delta(ChatCompat.toolCallDelta(delta, false))
			end)
	else
		result, err, provider_error = client:completeStream(compat.messages, compat.tools)
	end
	if not result then
		return nil, err, provider_error
	end
	return Provider.canonicalMessage(result)
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
