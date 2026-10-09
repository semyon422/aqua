local class = require("class")
local ZaiClient = require("ai.zai.Client")
local ZaiProxyServer = require("ai.zai.ProxyServer")
local Provider = require("ai.router.Provider")

-- Upstream adapter for a GLM Coding Plan subscription. Reuses the standalone
-- proxy's field allowlist and model resolution so router traffic follows the
-- same validation rules; request bodies are rebuilt, never forwarded verbatim.
---@class ai.router.ZaiProvider
---@operator call: ai.router.ZaiProvider
---@field models_set {[string]: boolean}
---@field model_redirects {[string]: string}
---@field thinking "enabled"|"disabled"?
---@field tool_stream boolean
---@field create_client fun(): zai.Client
local ZaiProvider = class()

---@class ai.router.ZaiProviderOptions
---@field config {[string]: any} subscription config: base_url, api_key, models, model_redirects?, thinking?, tool_stream?
---@field request zai.RequestFunc
---@field open_stream zai.OpenStreamFunc
---@field timeout number?

---@param options ai.router.ZaiProviderOptions
function ZaiProvider:new(options)
	local config = options.config
	assert(type(config.base_url) == "string" and config.base_url ~= "", "zai base_url is required")
	assert(type(config.api_key) == "string" and config.api_key ~= "", "zai api_key is required")
	assert(type(config.models) == "table" and #config.models > 0, "zai models are required")
	self.models_set = {}
	local config_models = config.models
	---@cast config_models string[]
	for _, model in ipairs(config_models) do
		self.models_set[model] = true
	end
	self.model_redirects = {}
	local config_redirects = config.model_redirects
	---@cast config_redirects {[string]: string}?
	for source, target in pairs(config_redirects or {}) do
		self.model_redirects[source] = target
	end
	self.thinking = config.thinking
	self.tool_stream = config.tool_stream ~= false
	local request = options.request
	local open_stream = options.open_stream
	self.create_client = function()
		return ZaiClient({
			base_url = config.base_url,
			api_key = config.api_key,
			timeout = options.timeout,
			request = request,
			open_stream = open_stream,
		})
	end
end

-- Validates and normalizes the request through the standalone proxy rules.
-- The caller sets body.model to the concrete chain entry; the provider maps
-- it through the subscription's permanent redirects.
---@param body table
---@return table? upstream_body
---@return string? public_model
---@return boolean stream
---@return boolean include_usage
---@return string? message
---@return string? code
function ZaiProvider:normalize(body)
	return ZaiProxyServer.normalizeRequest(body, self.models_set, self.model_redirects,
		self.thinking, self.tool_stream)
end

---@param body table
---@param _upstream_model string unused: normalize computes the redirected model
---@return ai.router.CanonicalMessage? message
---@return string? err
---@return zai.ProviderError? provider_error
function ZaiProvider:complete(body, _upstream_model)
	local upstream_body, _, _, _, message, code = self:normalize(body)
	if not upstream_body then
		return nil, nil, {status = 400, message = message, type = "invalid_request_error", code = code}
	end
	local completion, err, provider_error = self.create_client():complete(upstream_body)
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

-- Relays upstream Chat Completions deltas verbatim; the server wraps them
-- into chunks echoing the public model name.
---@param body table
---@param _upstream_model string unused: normalize computes the redirected model
---@param on_delta fun(delta: table): boolean?
---@return ai.router.CanonicalMessage? message
---@return string? err
---@return zai.ProviderError? provider_error
function ZaiProvider:completeStream(body, _upstream_model, on_delta)
	local upstream_body, _, _, _, message, code = self:normalize(body)
	if not upstream_body then
		return nil, nil, {status = 400, message = message, type = "invalid_request_error", code = code}
	end
	local message_result, err, provider_error = self.create_client():completeStream(upstream_body, on_delta)
	if not message_result then
		return nil, err, provider_error
	end
	return Provider.canonicalMessage(message_result)
end

return ZaiProvider
