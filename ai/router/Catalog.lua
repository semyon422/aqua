
---@class ai.router.SubscriptionState
---@field id integer
---@field name string
---@field kind "openai"|"zai"|"openai_compat"
---@field enabled boolean
---@field models {[string]: boolean} public model names this subscription serves
---@field model_redirects {[string]: string} permanent upstream renames
---@field five_hour_quota_tokens integer? local counting quota
---@field weekly_quota_tokens integer? local counting quota
---@field usage_source {five_hour: "upstream"|"local"?, weekly: "upstream"|"local"?}
---@field poll_interval integer? seconds

---@class ai.router.CatalogState
---@field subscriptions ai.router.SubscriptionState[] ordered by id
---@field alias_models {[string]: string} aliases to concrete model names
---@field concrete_models {[string]: boolean} union of every subscription's models, including disabled
---@field public_models {[string]: boolean} aliases plus enabled subscriptions' models

-- Builds the routing state from repository rows and validates it deeply.
-- Management saves call this before persisting; the runtime asserts a clean build.
-- Returns the state plus a list of human-readable errors; a state with errors
-- must not be served.
---@class ai.router.Catalog
local Catalog = {}

local window_names = {
	five_hour = true,
	weekly = true,
}

---@param label string
---@param errors string[]
---@param message string
local function fail(label, errors, message)
	table.insert(errors, label .. ": " .. message)
end

---@param value any
---@return boolean
local function isPlainObject(value)
	return type(value) == "table" and #value == 0
end

---@param config {[string]: any}
---@param allowed {[string]: boolean}
---@param label string
---@param errors string[]
local function assertKnownKeys(config, allowed, label, errors)
	for key in pairs(config) do
		if not allowed[key] then
			fail(label, errors, "unknown config field: " .. tostring(key))
		end
	end
end

---@param value any
---@param label string
---@param errors string[]
---@return string[]?
local function checkModelList(value, label, errors)
	if type(value) ~= "table" or #value == 0 then
		fail(label, errors, "models must be a non-empty list")
		return nil
	end
	---@cast value string[]
	---@type {[string]: boolean}
	local seen = {}
	for i, model in ipairs(value) do
		if type(model) ~= "string" or #model == 0 then
			fail(label, errors, ("models[%d] must be a non-empty string"):format(i))
			return nil
		end
		if seen[model] then
			fail(label, errors, "duplicate model: " .. model)
			return nil
		end
		seen[model] = true
	end
	return value
end

---@param value any
---@param label string
---@param errors string[]
---@return {[string]: string}?
local function checkRedirects(value, label, errors)
	if value == nil then return {} end
	if not isPlainObject(value) then
		fail(label, errors, "model_redirects must be an object")
		return nil
	end
	---@type {[string]: string}
	local redirects = {}
	---@cast value {[string]: any}
	for source, target in pairs(value) do
		if type(source) ~= "string" or type(target) ~= "string" or #target == 0 then
			fail(label, errors, "model_redirects must map model names to non-empty model names")
			return nil
		end
		if source == target then
			fail(label, errors, "model_redirects must not map a model to itself: " .. source)
			return nil
		end
		redirects[source] = target
	end
	return redirects
end

---@param row ai.router.SubscriptionRow
---@param errors string[]
---@return ai.router.SubscriptionState?
local function buildSubscription(row, errors)
	local label = "subscription " .. row.name
	if #row.name > 64 or not row.name:match("^[%w._%-]+$") then
		fail(label, errors, "name must contain only letters, digits, ._- and no slash")
		return nil
	end
	local state = {
		id = row.id,
		name = row.name,
		kind = row.kind,
		enabled = row.enabled,
		models = {},
		model_redirects = {},
		five_hour_quota_tokens = nil,
		weekly_quota_tokens = nil,
		usage_source = {},
		poll_interval = nil,
	}
	---@cast state ai.router.SubscriptionState

	local config = row.config
	if not isPlainObject(config) then
		fail(label, errors, "config must be an object")
		return nil
	end
	---@cast config {[string]: any}

	local models = checkModelList(config.models, label, errors)
	if not models then return nil end
	for _, model in ipairs(models) do
		state.models[model] = true
	end

	local redirects = checkRedirects(config.model_redirects, label, errors)
	if not redirects then return nil end
	for source in pairs(redirects) do
		if not state.models[source] then
			fail(label, errors, "model redirect source is not served by this subscription: " .. source)
			return nil
		end
	end
	state.model_redirects = redirects

	if row.kind == "openai" then
		assertKnownKeys(config, {
			auth_path = true,
			models = true,
			model_redirects = true,
			reasoning_effort = true,
			verbosity = true,
			max_response_size = true,
		}, label, errors)
		if type(config.auth_path) ~= "string" or #config.auth_path == 0 then
			fail(label, errors, "auth_path must be a non-empty string")
			return nil
		end
		local reasoning_effort = config.reasoning_effort
		if reasoning_effort ~= nil and reasoning_effort ~= "none"
			and reasoning_effort ~= "low" and reasoning_effort ~= "medium"
			and reasoning_effort ~= "high" then
			fail(label, errors, "reasoning_effort must be none, low, medium, or high")
			return nil
		end
		if config.verbosity ~= nil and config.verbosity ~= "low"
			and config.verbosity ~= "medium" and config.verbosity ~= "high" then
			fail(label, errors, "verbosity must be low, medium, or high")
			return nil
		end
		local size = config.max_response_size
		if size ~= nil and (type(size) ~= "number" or size % 1 ~= 0 or size < 1) then
			fail(label, errors, "max_response_size must be a positive integer")
			return nil
		end
	elseif row.kind == "zai" then
		assertKnownKeys(config, {
			base_url = true,
			api_key = true,
			models = true,
			model_redirects = true,
			thinking = true,
			tool_stream = true,
			usage_url = true,
		}, label, errors)
		if type(config.base_url) ~= "string" or not config.base_url:match("^https?://") then
			fail(label, errors, "base_url must be an http(s) URL")
			return nil
		end
		local usage_url = config.usage_url
		if usage_url ~= nil and (type(usage_url) ~= "string" or not usage_url:match("^https?://")) then
			fail(label, errors, "usage_url must be an http(s) URL")
			return nil
		end
		if type(config.api_key) ~= "string" or #config.api_key == 0 then
			fail(label, errors, "api_key must be a non-empty string")
			return nil
		end
		if config.thinking ~= nil and config.thinking ~= "enabled" and config.thinking ~= "disabled" then
			fail(label, errors, "thinking must be enabled or disabled")
			return nil
		end
		if config.tool_stream ~= nil and type(config.tool_stream) ~= "boolean" then
			fail(label, errors, "tool_stream must be a boolean")
			return nil
		end
	else
		assertKnownKeys(config, {
			base_url = true,
			api_key = true,
			models = true,
			model_redirects = true,
		}, label, errors)
		if type(config.base_url) ~= "string" or not config.base_url:match("^https?://") then
			fail(label, errors, "base_url must be an http(s) URL")
			return nil
		end
		if config.api_key ~= nil and (type(config.api_key) ~= "string" or #config.api_key == 0) then
			fail(label, errors, "api_key must be a non-empty string when set")
			return nil
		end
	end

	local limits = row.limits
	if not isPlainObject(limits) then
		fail(label, errors, "limits must be an object")
		return nil
	end
	---@cast limits {[string]: any}
	assertKnownKeys(limits, {
		five_hour_quota_tokens = true,
		weekly_quota_tokens = true,
		usage_source = true,
		poll_interval = true,
	}, label, errors)

	---@param key string
	---@param minimum integer
	---@return integer? value nil when unset or invalid
	local function checkPositiveInteger(key, minimum)
		local value = limits[key]
		if value == nil then return nil end
		if type(value) ~= "number" or value % 1 ~= 0 or value < minimum then
			fail(label, errors, key .. (" must be an integer of at least %d"):format(minimum))
			return nil
		end
		return value
	end

	local errors_before = #errors
	state.five_hour_quota_tokens = checkPositiveInteger("five_hour_quota_tokens", 1)
	state.weekly_quota_tokens = checkPositiveInteger("weekly_quota_tokens", 1)
	if #errors > errors_before then return nil end

	if limits.usage_source ~= nil then
		local usage_source = limits.usage_source
		if not isPlainObject(usage_source) then
			fail(label, errors, "usage_source must be an object")
			return nil
		end
		---@cast usage_source {[string]: any}
		assertKnownKeys(usage_source, {five_hour = true, weekly = true}, label .. " usage_source", errors)
		local five_hour = usage_source.five_hour
		if five_hour ~= nil and five_hour ~= "upstream" and five_hour ~= "local" then
			fail(label, errors, "usage_source.five_hour must be upstream or local")
			return nil
		end
		local weekly = usage_source.weekly
		if weekly ~= nil and weekly ~= "upstream" and weekly ~= "local" then
			fail(label, errors, "usage_source.weekly must be upstream or local")
			return nil
		end
		state.usage_source = {five_hour = five_hour, weekly = weekly}
	end
	state.poll_interval = checkPositiveInteger("poll_interval", 5)

	return state
end

-- Default usage sources: providers with a known upstream monitor endpoint use
-- it; local llama.cpp has none and counts locally.
local default_usage_source = {
	openai = "upstream",
	zai = "upstream",
	openai_compat = "local",
}

---@param subscription_rows ai.router.SubscriptionRow[]
---@param model_rows ai.router.ModelRow[]
---@return ai.router.CatalogState state
---@return string[] errors
function Catalog.fromRows(subscription_rows, model_rows)
	---@type string[]
	local errors = {}
	---@type ai.router.CatalogState
	local state = {
		subscriptions = {},
		alias_models = {},
		concrete_models = {},
		public_models = {},
	}

	---@type ai.router.SubscriptionState[]
	local subscription_states = {}
	for _, row in ipairs(subscription_rows) do
		local sub_state = buildSubscription(row, errors)
		if sub_state then
			table.insert(subscription_states, sub_state)
			for model in pairs(sub_state.models) do
				local qualified = sub_state.name .. "/" .. model
				state.concrete_models[qualified] = true
				if sub_state.enabled then
					state.public_models[qualified] = true
				end
			end
		end
	end

	-- Alias names are collected first so target validation also catches aliases
	-- defined later in the list.
	---@type {[string]: boolean}
	local alias_names = {}
	for _, row in ipairs(model_rows) do
		alias_names[row.name] = true
	end

	for _, row in ipairs(model_rows) do
		local label = "model " .. row.name
		if row.name:find("/", 1, true) then
			fail(label, errors, "alias name must not contain a slash")
		elseif state.concrete_models[row.name] then
			fail(label, errors, "alias must not shadow a concrete model name")
		else
			if type(row.target) ~= "string" or #row.target < 1 or #row.target > 193 then
				fail(label, errors, "alias target must be a 1-193 character subscription/model name")
			elseif alias_names[row.target] then
				fail(label, errors, "alias target must not reference a custom model: " .. row.target)
			elseif not state.concrete_models[row.target] then
				fail(label, errors, "alias target is not served by any subscription: " .. row.target)
			else
				state.alias_models[row.name] = row.target
				state.public_models[row.name] = true
			end
		end
	end

	table.sort(subscription_states, function(a, b)
		return a.id < b.id
	end)
	state.subscriptions = subscription_states

	for _, sub_state in ipairs(state.subscriptions) do
		for _, window in ipairs({"five_hour", "weekly"}) do
			if sub_state.usage_source[window] == nil then
				sub_state.usage_source[window] = default_usage_source[sub_state.kind]
			end
		end
	end

	return state, errors
end

return Catalog
