local json = require("web.json")

---@class zai.UsageClientOptions
---@field request openai.RequestFunc
---@field api_key string
---@field url string?
---@field timeout number?

-- Stateless Coding Plan monitor fetcher. The caller supplies network/TLS
-- policy and the key; window parsing and polling remain independent.
local UsageClient = {}
UsageClient.url = "https://api.z.ai/api/monitor/usage/quota/limit"

---@param options zai.UsageClientOptions
---@return table? data Raw unwrapped monitor data.
---@return string? err
---@return openai.UsageFetchError? failure
function UsageClient.fetch(options)
	assert(type(options.request) == "function", "request is required")
	assert(type(options.api_key) == "string" and options.api_key ~= "", "api_key is required")
	local response, request_err = options.request(options.url or UsageClient.url, nil, {
		method = "GET", timeout = options.timeout,
		headers = {Accept = "application/json", Authorization = "Bearer " .. options.api_key},
	})
	if not response then
		return nil, request_err or "Z.ai usage request failed",
			{code = "transport", message = "Z.ai usage request failed", type = "upstream_error"}
	end
	if response.status < 200 or response.status >= 300 then
		return nil, "Z.ai usage request failed", {
			status = response.status, message = "Z.ai usage request failed", type = "upstream_error", code = "upstream_http",
		}
	end
	local usage = json.decode_safe(response.body)
	if type(usage) ~= "table" or not json.isObject(usage) then
		return nil, "invalid Z.ai usage response",
			{code = "invalid_response", message = "invalid Z.ai usage response", type = "upstream_error"}
	end
	if type(usage.data) ~= "table" or not json.isObject(usage.data) then
		return nil, "invalid Z.ai usage response: data object is missing",
			{code = "invalid_response", message = "invalid Z.ai usage response: data object is missing", type = "upstream_error"}
	end
	return usage.data
end

return UsageClient
