local class = require("class")
local ZaiClient = require("ai.zai.Client")
local Provider = require("ai.router.Provider")

-- Upstream adapter for a trusted local OpenAI-compatible endpoint such as
-- llama.cpp. No field allowlist is applied: the validated client body is
-- forwarded verbatim with only the model name replaced, and deltas are
-- relayed unchanged.
---@class ai.router.CompatProvider
---@operator call: ai.router.CompatProvider
---@field create_client fun(): zai.Client
local CompatProvider = class()

---@class ai.router.CompatProviderOptions
---@field config {[string]: any} subscription config: base_url, api_key?, models
---@field request zai.RequestFunc
---@field open_stream zai.OpenStreamFunc
---@field timeout number?

---@param options ai.router.CompatProviderOptions
function CompatProvider:new(options)
	local config = options.config
	assert(type(config.base_url) == "string" and config.base_url ~= "", "compat base_url is required")
	assert(type(config.models) == "table" and #config.models > 0, "compat models are required")
	-- Endpoints without authentication ignore the bearer header; a placeholder
	-- keeps the shared client's non-empty key invariant.
	local api_key = config.api_key
	if api_key == nil or api_key == "" then
		api_key = "local-compat-endpoint"
	end
	local request = options.request
	local open_stream = options.open_stream
	self.create_client = function()
		return ZaiClient({
			base_url = config.base_url,
			api_key = api_key,
			timeout = options.timeout,
			request = request,
			open_stream = open_stream,
		})
	end
end

-- Copies the request body and sends the resolved upstream model name.
---@param body table
---@param upstream_model string
---@return table upstream_body
function CompatProvider.upstreamBody(body, upstream_model)
	---@type {[string]: any}
	local upstream_body = {}
	---@cast body {[string]: any}
	for key, value in pairs(body) do
		upstream_body[key] = value
	end
	upstream_body.model = upstream_model
	return upstream_body
end

---@param body table
---@param upstream_model string
---@return ai.router.CanonicalMessage? message
---@return string? err
---@return zai.ProviderError? provider_error
function CompatProvider:complete(body, upstream_model)
	local completion, err, provider_error = self.create_client():complete(CompatProvider.upstreamBody(body, upstream_model))
	if not completion then
		return nil, err, provider_error
	end
	---@cast completion {[string]: any}
	local choice = Provider.completionChoice(completion)
	---@type ai.router.CanonicalMessage
	local canonical = Provider.canonicalMessage(choice.message)
	if type(choice.finish_reason) == "string" then
		canonical.finish_reason = choice.finish_reason
	end
	if not canonical.usage then
		canonical.usage = Provider.canonicalUsage(completion.usage)
	end
	return canonical
end

---@param body table
---@param upstream_model string
---@param on_delta fun(delta: table): boolean?
---@return ai.router.CanonicalMessage? message
---@return string? err
---@return zai.ProviderError? provider_error
function CompatProvider:completeStream(body, upstream_model, on_delta)
	local message, err, provider_error = self.create_client():completeStream(
		CompatProvider.upstreamBody(body, upstream_model), on_delta)
	if not message then
		return nil, err, provider_error
	end
	return Provider.canonicalMessage(message)
end

return CompatProvider
