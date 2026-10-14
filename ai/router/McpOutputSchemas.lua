local json = require("web.json")

---@class ai.router.McpOutputSchemas
local McpOutputSchemas = {}

---@param properties {[string]: mcp.JsonSchema}
---@param required string[]?
---@return mcp.JsonSchemaObject
local function object(properties, required)
	return {type = "object", properties = json.object(properties),
		required = json.array(required or {}), additionalProperties = false}
end

---@param items mcp.JsonSchema
---@return mcp.JsonSchemaObject
local function array(items)
	return {type = "array", items = items}
end

---@param values string[]
---@return mcp.JsonSchemaObject
local function enum(values)
	return {type = "string", enum = values}
end

local text = {type = "string"}
local integer = {type = "integer"}
local number = {type = "number"}
local flag = {type = "boolean"}
local strings = array(text)
local login_status = enum({"unauthenticated", "logging_in", "authenticated", "error"})
local source = enum({"local", "upstream"})
local operation = object({
	persistence = enum({"committed", "not_committed", "not_attempted", "unknown"}),
	reload = enum({"applied", "failed", "not_required", "not_attempted"}),
}, {"persistence", "reload"})
local user = object({id = integer, name = text, key_hint = text, disabled = flag,
	max_concurrency = integer, max_rpm = integer, created_at = integer, updated_at = integer, models = strings},
	{"id", "name", "key_hint", "disabled", "created_at", "updated_at", "models"})
local config = object({models = strings, model_redirects = {type = "object", additionalProperties = text},
	base_url = text, usage_url = text,
	reasoning_effort = enum({"none", "low", "medium", "high"}), verbosity = enum({"low", "medium", "high"}),
	max_response_size = integer, thinking = enum({"enabled", "disabled"}), tool_stream = flag})
local limits = object({
	five_hour_quota_tokens = integer, weekly_quota_tokens = integer, poll_interval = integer,
	usage_source = object({five_hour = source, weekly = source})})
local channel = object({id = integer, name = text, kind = enum({"openai", "zai", "openai_compat"}),
	enabled = flag, config = config, limits = limits, has_api_key = flag,
	created_at = integer, updated_at = integer, login_status = login_status},
	{"id", "name", "kind", "enabled", "config", "limits", "has_api_key", "created_at", "updated_at"})
local model = object({id = integer, name = text, target = text, description = text,
	created_at = integer, updated_at = integer}, {"id", "name", "target", "created_at", "updated_at"})
local window = object({used_percent = number, used_tokens = integer, quota_tokens = integer,
	reset_at = integer, source = source, updated_at = number}, {"source", "updated_at"})
local status = object({id = integer, name = text, enabled = flag,
	windows = object({five_hour = window, weekly = window}), login_status = login_status},
	{"id", "name", "enabled", "windows"})
local usage = object({bucket = integer, user = text, model = text, upstream_model = text, channel = text,
	requests = integer, errors = integer, input_tokens = integer, output_tokens = integer,
	cached_input_tokens = integer, estimated_requests = integer, cost_usd = number, cache_savings_usd = number},
	{"bucket", "user", "model", "upstream_model", "channel", "requests", "errors", "input_tokens",
		"output_tokens", "cached_input_tokens", "estimated_requests", "cost_usd", "cache_savings_usd"})
local login = object({status = login_status, verification_url = text, user_code = text,
	expires_at = number, error = text}, {"status"})

---@type {[string]: mcp.JsonSchemaObject}
local results = {
	listUsers = object({users = array(user)}, {"users"}),
	listChannels = object({channels = array(channel)}, {"channels"}),
	listModels = object({public_models = strings, aliases = array(model)}, {"public_models", "aliases"}),
	status = object({now = integer, channels = array(status), catalog_reload_pending = flag},
		{"now", "channels", "catalog_reload_pending"}),
	usage = object({hours = {type = "integer", enum = {24, 168}}, rows = array(usage)}, {"hours", "rows"}),
	createUser = object({user = user, api_key = text}, {"user", "api_key"}),
	updateUser = object({user = user}, {"user"}),
	regenerateKey = object({id = integer, api_key = text}, {"id", "api_key"}),
	deleteUser = object({deleted_id = integer}, {"deleted_id"}),
	saveChannel = object({channel = channel}, {"channel"}),
	deleteChannel = object({deleted_id = integer}, {"deleted_id"}),
	saveModel = object({model = model}, {"model"}),
	deleteModel = object({deleted_id = integer}, {"deleted_id"}),
	startLogin = object({id = integer, login = login}, {"id", "login"}),
	loginStatus = object({id = integer, login = login}, {"id", "login"}),
	refreshUsage = object({scheduled_id = integer}, {"scheduled_id"}),
	testChannel = object({probe = object({id = integer, channel = text, model = text, upstream_model = text,
		protocol = enum({"responses", "chat_completions"}), ok = flag, status = integer,
		duration_ms = {type = "integer", minimum = 0},
		error_code = enum({"rate_limit", "concurrency_limit", "timeout", "auth", "client_disconnected", "model_not_found",
			"unsupported_protocol", "invalid_request", "upstream_unavailable", "upstream_error", "internal_error"}),
		input_tokens = integer, output_tokens = integer, cached_input_tokens = integer},
		{"id", "channel", "model", "upstream_model", "protocol", "ok", "status", "duration_ms"})}, {"probe"}),
	reloadCatalog = object({operation = operation, error = text}, {"operation"}),
}

---@param method string
---@param mutation boolean
---@return mcp.JsonSchemaObject
function McpOutputSchemas.get(method, mutation)
	local success = assert(results[method])
	-- Copy before adding transaction metadata; shared definitions stay immutable.
	---@type {[string]: mcp.JsonSchema}
	local properties = {}
	for key, value in pairs(success.properties) do properties[key] = value end
	---@type string[]
	local required = {}
	for _, key in ipairs(success.required) do table.insert(required, key) end
	if mutation then
		properties.operation, properties.error = operation, text
		table.insert(required, "operation")
	end
	return {type = "object", anyOf = {
		object(properties, required),
		object({error = text, operation = operation}, mutation and {"error", "operation"} or {"error"}),
	}}
end

return McpOutputSchemas
