local json = require("web.json")
local McpTool = require("ai.router.McpTool")
local McpOutputSchemas = require("ai.router.McpOutputSchemas")

---@class ai.router.McpTools
local McpTools = {}

---@param properties table
---@param required string[]?
---@return table
local function object(properties, required)
	return {type = "object", properties = json.object(properties),
		required = json.array(required or {}), additionalProperties = false}
end

local id = {type = "integer", minimum = 1}
local name = {type = "string"}
local model_name = {type = "string"}
local models = {type = "array", items = model_name, maxItems = 1024}
local positive = {type = "integer", minimum = 1}
local flag = {type = "boolean"}
local text = {type = "string"}
local config = object({
	models = models, auth_path = text, base_url = text, api_key = text, usage_url = text,
	model_redirects = {type = "object", additionalProperties = {type = "string"}},
	reasoning_effort = {type = "string", enum = {"none", "low", "medium", "high"}},
	verbosity = {type = "string", enum = {"low", "medium", "high"}},
	max_response_size = positive, thinking = {type = "string", enum = {"enabled", "disabled"}}, tool_stream = flag,
})
local threshold = {type = "number", minimum = 0, maximum = 100}
local source = {type = "string", enum = {"local", "upstream"}}
local limits = object({five_hour_threshold = threshold, weekly_threshold = threshold,
	five_hour_quota_tokens = positive, weekly_quota_tokens = positive,
	usage_source = object({five_hour = source, weekly = source}), poll_interval = positive})

---@param management ai.router.Management
---@return mcp.Tool[]
function McpTools.create(management)
	---@type mcp.Tool[]
	local tools = {}
	---@param tool_name string
	---@param method string
	---@param description string
	---@param schema table
	---@param mutation boolean?
	---@param destructive boolean?
	---@param external boolean?
	local function add(tool_name, method, description, schema, mutation, destructive, external)
		table.insert(tools, McpTool(management, {
			name = tool_name, method = method,
			description = description .. (mutation and " Results include operation.persistence and operation.reload. A committed mutation with failed reload must not be replayed; use router_reload_catalog instead." or ""),
			input_schema = schema,
			output_schema = McpOutputSchemas.get(method, mutation == true),
			mutation = mutation == true,
			annotations = {readOnlyHint = not mutation and not external, destructiveHint = destructive == true,
				openWorldHint = external == true},
		}))
	end
	add("router_list_users", "listUsers", "List users, grants, limits, and key hints. Never returns stored key hashes or API keys.", object({}))
	add("router_list_subscriptions", "listSubscriptions", "List subscriptions and redacted config. Credentials are never returned.", object({}))
	add("router_list_models", "listModels", "List public models and aliases with their single concrete model target.", object({}))
	add("router_status", "status", "Read usage windows, freshness timestamps, cooldowns, and OAuth status.", object({}))
	add("router_usage", "usage", "Read hourly usage and cost aggregates for the last 24 or 168 hours. No message content.", object({hours = {type = "integer", enum = {24, 168}}}))
	add("router_create_user", "createUser", "Create a user with model grants. Returns a new API key ONCE: treat the result as a secret.", object({name = name, models = models}, {"name", "models"}), true)
	add("router_update_user", "updateUser", "Patch a user: rename, disable/enable, replace grants, or set positive concurrency/RPM limits. Omitted fields are unchanged.", object({id = id, name = name, models = models, disabled = flag, max_concurrency = positive, max_rpm = positive}, {"id"}), true, true)
	add("router_regenerate_key", "regenerateKey", "Revoke the user's current key and return a replacement ONCE. Treat the result as a secret.", object({id = id}, {"id"}), true, true)
	add("router_delete_user", "deleteUser", "Delete a user and all grants; immediately revoke access.", object({id = id}, {"id"}), true, true)
	add("router_save_subscription", "saveSubscription", "Create (omit id) or patch a subscription. Creation requires name, kind, priority, config.models and kind-specific credentials/URL. OpenAI auth_path is generated if omitted. Config fields are merged on same-kind edits, preserving unreadable credentials; limits replace the entire limits object. Omitted fields remain unchanged. Catalog is validated before saving; pending OAuth blocks edits.", object({id = id, name = name,
		kind = {type = "string", enum = {"openai", "zai", "openai_compat"}}, priority = {type = "integer"},
		enabled = flag, config = config, limits = limits}), true, true)
	add("router_delete_subscription", "deleteSubscription", "Delete a subscription if no alias depends on its models and no OAuth login is pending. Credential files are not removed.", object({id = id}, {"id"}), true, true)
	add("router_save_model", "saveModel", "Create (omit id) or patch a simple alias to one concrete model. Creation requires name and target; nested aliases and self-references are rejected. Failover only uses subscriptions serving that same model.", object({id = id, name = model_name,
		target = model_name, description = {type = "string"}}), true, true)
	add("router_delete_model", "deleteModel", "Delete a custom model alias. Existing user grants are kept but the model becomes unavailable.", object({id = id}, {"id"}), true, true)
	add("router_start_openai_login", "startLogin", "Start background OpenAI device authorization. Poll router_openai_login_status to obtain the verification URL and code and later the result. The user must approve in their browser; never approve for them.", object({id = id}, {"id"}), false, false, true)
	add("router_openai_login_status", "loginStatus", "Get OpenAI device login status, verification URL, one-time code and expiry. Never returns tokens or private device IDs.", object({id = id}, {"id"}))
	add("router_refresh_usage", "refreshUsage", "Schedule an immediate usage poll for a subscription; inspect router_status afterward.", object({id = id}, {"id"}), false, false, true)
	add("router_reload_catalog", "reloadCatalog", "Retry applying the saved catalog to routing and providers without replaying database mutations. Use after operation.reload=failed; inspect router_status.catalog_reload_pending. Mutation results report operation.persistence and operation.reload even when isError=true.", object({}), false, false, true)
	return tools
end

return McpTools
