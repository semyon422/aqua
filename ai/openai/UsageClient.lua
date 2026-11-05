local json = require("web.json")
local random = require("web.random")

---@alias openai.UsageFetchErrorCode "auth"|"transport"|"upstream_http"|"cloudflare_challenge"|"invalid_response"

---@class openai.UsageFetchError
---@field code openai.UsageFetchErrorCode
---@field status integer? Actual upstream HTTP status; absent for local/transport failures.
---@field message string
---@field type string
---@field request_id string?

---@class openai.UsageClientOptions
---@field request openai.RequestFunc
---@field auth openai.ISubscriptionAuth
---@field url string?
---@field originator string? Also used as User-Agent; defaults to openai-proxy.
---@field timeout number?

-- Stateless HTTP fetcher. OAuth refresh/serialization and networking are
-- supplied by the caller; quota parsing, polling and persistence stay outside.
local UsageClient = {}
UsageClient.url = "https://chatgpt.com/backend-api/codex/usage"

---@param options openai.UsageClientOptions
---@return table? usage Raw Codex usage object.
---@return string? err
---@return openai.UsageFetchError? failure
function UsageClient.fetch(options)
	assert(type(options.request) == "function", "request is required")
	assert(options.auth and type(options.auth.getAccess) == "function", "auth is required")
	local access_token, account_id, access_err = options.auth:getAccess()
	if not access_token then
		return nil, access_err or "OpenAI login is required",
			{code = "auth", message = "OpenAI login is required", type = "upstream_error"}
	end
	if not account_id or account_id == "" then
		return nil, "OpenAI login has no account ID",
			{code = "auth", message = "OpenAI login has no account ID", type = "upstream_error"}
	end
	local client_request_id = random.hex(16)
	local originator = options.originator or "openai-proxy"
	local response, request_err = options.request(options.url or UsageClient.url, nil, {
		method = "GET", timeout = options.timeout,
		headers = {
			Authorization = "Bearer " .. access_token,
			["ChatGPT-Account-Id"] = account_id,
			Accept = "application/json",
			Originator = originator,
			["User-Agent"] = originator,
			["x-client-request-id"] = client_request_id,
		},
	})
	if not response then
		return nil, request_err or "OpenAI usage request failed",
			{code = "transport", message = "OpenAI usage request failed", type = "upstream_error"}
	end
	if response.status < 200 or response.status >= 300 then
		local request_id = response.headers and response.headers:get("x-request-id")
		if type(request_id) ~= "string" or request_id == "" or #request_id > 128 or request_id:find("[%c\127]") then
			request_id = client_request_id
		end
		local challenged = response.headers and response.headers:get("cf-mitigated") == "challenge"
		return nil, "OpenAI usage request failed", {
			status = response.status, message = "OpenAI usage request failed", type = "upstream_error",
			code = challenged and "cloudflare_challenge" or "upstream_http", request_id = request_id,
		}
	end
	local usage = json.decode_safe(response.body)
	if type(usage) ~= "table" or not json.isObject(usage) then
		return nil, "invalid OpenAI usage response",
			{code = "invalid_response", message = "invalid OpenAI usage response", type = "upstream_error"}
	end
	return usage
end

return UsageClient
