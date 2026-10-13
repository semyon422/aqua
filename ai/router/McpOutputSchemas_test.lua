local JsonSchema = require("mcp.JsonSchema")
local McpOutputSchemas = require("ai.router.McpOutputSchemas")
local McpTool = require("ai.router.McpTool")
local json = require("web.json")

local test = {}

---@param t testing.T
function test.required_payloads_and_redaction(t)
	local schema = McpOutputSchemas.get("listUsers", false)
	t:assert(JsonSchema.validate(schema, {users = json.array({})}))
	t:eq(JsonSchema.validate(schema, {}), nil)
	t:eq(JsonSchema.validate(schema, {users = json.object({})}), nil)
	local user = {id = 1, name = "user", key_hint = "abcd", disabled = false,
		created_at = 1, updated_at = 1, models = {"model"}}
	t:assert(JsonSchema.validate(schema, {users = {user}}))
	user.key_hash = "SECRET"
	t:eq(JsonSchema.validate(schema, {users = {user}}), nil)
	local subscriptions = McpOutputSchemas.get("listSubscriptions", false)
	local row = {id = 1, name = "provider", kind = "openai_compat", priority = 1, enabled = true,
		config = {models = {"model"}}, limits = {}, has_api_key = true, created_at = 1, updated_at = 1}
	t:assert(JsonSchema.validate(subscriptions, {subscriptions = {row}}))
	row.config.api_key = "SECRET"
	t:eq(JsonSchema.validate(subscriptions, {subscriptions = {row}}), nil)
end

---@param t testing.T
function test.errors_and_committed_payloads(t)
	local schema = McpOutputSchemas.get("deleteSubscription", true)
	local result = {deleted_id = 1, operation = {persistence = "committed", reload = "failed"}, error = "reload failed"}
	t:assert(JsonSchema.validate(schema, result))
	t:assert(JsonSchema.validate(schema, {error = "validation failed",
		operation = {persistence = "not_committed", reload = "not_attempted"}}))
	result.operation.reload = "unexpected"
	t:eq(JsonSchema.validate(schema, result), nil)
	t:eq(JsonSchema.validate(schema, {deleted_id = 1}), nil)
	t:eq(JsonSchema.validate(schema, {error = "failed", secret = "SECRET"}), nil)
	t:eq(JsonSchema.validate(schema, {error = "failed"}), nil)
end

---@param t testing.T
function test.populated_windows_and_usage(t)
	local status = {now = 100, catalog_reload_pending = false, subscriptions = {
		{id = 1, name = "provider", enabled = true, cooldown_until = 200, login_status = "authenticated",
			windows = {five_hour = {source = "upstream", updated_at = 100.5, used_percent = 20, reset_at = 300},
				weekly = {source = "local", updated_at = 100, used_tokens = 10, quota_tokens = 100}}},
	}}
	t:assert(JsonSchema.validate(McpOutputSchemas.get("status", false), status))
	status.subscriptions[1].windows.weekly.source = "invalid"
	t:eq(JsonSchema.validate(McpOutputSchemas.get("status", false), status), nil)
	local row = {bucket = 0, user = "user", model = "alias", upstream_model = "model", subscription = "provider",
		requests = 1, errors = 0, input_tokens = 10, output_tokens = 2, cached_input_tokens = 5,
		estimated_requests = 0, cost_usd = 0.0001, cache_savings_usd = 0.00001}
	t:assert(JsonSchema.validate(McpOutputSchemas.get("usage", false), {hours = 24, rows = {row}}))
	row.cost_usd = nil
	t:eq(JsonSchema.validate(McpOutputSchemas.get("usage", false), {hours = 24, rows = {row}}), nil)
end

---@param t testing.T
function test.invalid_output_preserves_commit_metadata(t)
	local management = {execute = function()
		return {deleted_id = "bad", unexpected_secret = "SECRET",
			operation = {persistence = "committed", reload = "applied"}}
	end}
	local tool = McpTool(management, {name = "test", method = "deleteUser", description = "test",
		input_schema = {}, output_schema = McpOutputSchemas.get("deleteUser", true), mutation = true, annotations = {}})
	local text, is_error, result = tool:execute({})
	t:eq(is_error, true)
	t:tdeq(result.operation, {persistence = "committed", reload = "applied"})
	t:eq(text:find("SECRET", 1, true), nil)
	t:assert(JsonSchema.validate(tool.output_schema, result))
	management.execute = function() error("SECRET") end
	local _, failed, failure = tool:execute({})
	t:eq(failed, true)
	t:tdeq(failure.operation, {persistence = "unknown", reload = "not_attempted"})
	t:assert(JsonSchema.validate(tool.output_schema, failure))
end

return test
