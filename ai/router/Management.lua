local class = require("class")
local json = require("web.json")
local random = require("web.random")
local Catalog = require("ai.router.Catalog")

---@class ai.router.ManagementOptions
---@field users_repo ai.router.UsersRepo
---@field subscriptions_repo ai.router.SubscriptionsRepo
---@field models_repo ai.router.ModelsRepo
---@field usage_repo ai.router.UsageRepo
---@field monitor ai.router.UsageMonitor
---@field server ai.router.Server
---@field openai_login ai.router.OpenAILoginManager?
---@field get_time (fun(): integer)?

---@class ai.router.Management: ai.router.ManagementOptions
---@operator call: ai.router.Management
---@field catalog_reload_pending boolean
local Management = class()

---@alias ai.router.ManagementPersistence "committed"|"not_committed"|"not_attempted"|"unknown"
---@alias ai.router.ManagementReload "applied"|"failed"|"not_required"|"not_attempted"
---@class ai.router.ManagementOperation
---@field persistence ai.router.ManagementPersistence
---@field reload ai.router.ManagementReload

---@class ai.router.ManagementReloadResult
---@field operation ai.router.ManagementOperation
---@field error string?

---@class ai.router.PublicUser
---@field id integer
---@field name string
---@field key_hint string
---@field disabled boolean
---@field max_concurrency integer?
---@field max_rpm integer?
---@field created_at integer
---@field updated_at integer
---@field models string[]

---@class ai.router.PublicSubscriptionConfig
---@field models string[]?
---@field model_redirects {[string]: string}?
---@field auth_path string?
---@field base_url string?
---@field usage_url string?
---@field reasoning_effort "none"|"low"|"medium"|"high"?
---@field verbosity "low"|"medium"|"high"?
---@field max_response_size integer?
---@field thinking "enabled"|"disabled"?
---@field tool_stream boolean?

---@class ai.router.PublicSubscriptionLimits
---@field five_hour_threshold number?
---@field weekly_threshold number?
---@field five_hour_quota_tokens integer?
---@field weekly_quota_tokens integer?
---@field poll_interval integer?
---@field usage_source {five_hour: ("local"|"upstream")?, weekly: ("local"|"upstream")?}?

---@class ai.router.PublicSubscription
---@field id integer
---@field name string
---@field kind "openai"|"zai"|"openai_compat"
---@field priority integer
---@field enabled boolean
---@field config ai.router.PublicSubscriptionConfig
---@field limits ai.router.PublicSubscriptionLimits
---@field has_api_key boolean
---@field created_at integer
---@field updated_at integer
---@field login_status openai.SubscriptionAuthStatus?

---@class ai.router.ManagementSubscriptionStatus
---@field id integer
---@field name string
---@field enabled boolean
---@field windows {five_hour: ai.router.WindowSnapshot?, weekly: ai.router.WindowSnapshot?}
---@field cooldown_until number?
---@field login_status openai.SubscriptionAuthStatus?

---@class ai.router.ManagementResultMetadata
---@field operation ai.router.ManagementOperation?
---@field error string?

---@class ai.router.ManagementResult: ai.router.ManagementResultMetadata
---@field users ai.router.PublicUser[]?
---@field subscriptions ai.router.PublicSubscription[]|ai.router.ManagementSubscriptionStatus[]?
---@field public_models string[]?
---@field aliases ai.router.ModelRow[]?
---@field now integer?
---@field catalog_reload_pending boolean?
---@field hours integer?
---@field rows ai.router.UsageRow[]?
---@field user ai.router.PublicUser?
---@field api_key string?
---@field id integer?
---@field deleted_id integer?
---@field subscription ai.router.PublicSubscription?
---@field model ai.router.ModelRow?
---@field login ai.router.OpenAILoginState?
---@field scheduled_id integer?

---@type {[string]: boolean}
local catalog_mutations = {saveSubscription = true, deleteSubscription = true, saveModel = true, deleteModel = true}
local reload_error = "Changes are saved, but catalog reload failed. Do not repeat the mutation; call router_reload_catalog to retry applying the saved catalog."

---@param options ai.router.ManagementOptions
function Management:new(options)
	for key, value in pairs(options) do self[key] = value end
	self.get_time = options.get_time or os.time
	self.catalog_reload_pending = false
end

---@param condition any
---@param message string
local function check(condition, message)
	if not condition then error({management_error = message}, 0) end
end

---@param value string
---@param label string
local function checkName(value, label)
	check(type(value) == "string" and #value >= 1 and #value <= 64, label .. " name must be 1-64 characters.")
end

---@param models string[]
local function checkGrants(models)
	---@type {[string]: boolean}
	local seen = {}
	for _, model in ipairs(models) do
		check(#model >= 1 and #model <= 128, "Granted model names must be 1-128 characters.")
		check(not seen[model], "Duplicate granted model.")
		seen[model] = true
	end
end

---@param rows table[]
---@param id integer?
---@param replacement table?
---@return table[]
local function replace(rows, id, replacement)
	local result = {}
	for _, row in ipairs(rows) do
		if row.id ~= id then table.insert(result, row) end
	end
	if replacement then table.insert(result, replacement) end
	return result
end

---@param subscriptions ai.router.SubscriptionRow[]
---@param models ai.router.ModelRow[]
local function validateCatalog(subscriptions, models)
	local _, errors = Catalog.fromRows(subscriptions, models)
	-- Catalog diagnostics may contain operator-supplied values; never reflect them.
	check(#errors == 0, "Invalid catalog: check subscription config, limits, redirects, and alias targets.")
	---@type {[string]: boolean}
	local paths = {}
	for _, row in ipairs(subscriptions) do
		if row.kind == "openai" then
			check(not paths[row.config.auth_path], "Each OpenAI subscription requires a distinct auth_path.")
			paths[row.config.auth_path] = true
		end
	end
end

---@param row ai.router.UserRow
---@return ai.router.PublicUser
function Management:publicUser(row)
	return {id = row.id, name = row.name, key_hint = row.key_hint, disabled = row.disabled,
		max_concurrency = row.max_concurrency, max_rpm = row.max_rpm,
		created_at = row.created_at, updated_at = row.updated_at,
		models = json.array(self.users_repo:getGrants(row.id))}
end

---@param row ai.router.SubscriptionRow
---@return ai.router.PublicSubscription
function Management:publicSubscription(row)
	---@type ai.router.PublicSubscriptionConfig
	local config = json.object({})
	for _, key in ipairs({"models", "model_redirects", "auth_path", "base_url", "usage_url",
		"reasoning_effort", "verbosity", "max_response_size", "thinking", "tool_stream"}) do
		local value = row.config[key]
		if (key == "base_url" or key == "usage_url") and type(value) == "string"
			and value:find("[@?#]") then value = "[redacted URL]" end
		if key == "model_redirects" and value then
			local redirects = json.object({})
			for source, target in pairs(value) do redirects[source] = target end
			value = redirects
		end
		config[key] = value
	end
	---@type ai.router.PublicSubscriptionLimits
	local limits = json.object({})
	for key, value in pairs(row.limits) do
		if key == "usage_source" then
			local sources = json.object({})
			for window, source in pairs(value) do sources[window] = source end
			value = sources
		end
		limits[key] = value
	end
	return {id = row.id, name = row.name, kind = row.kind, priority = row.priority,
		enabled = row.enabled, config = config, limits = limits,
		has_api_key = row.config.api_key ~= nil, created_at = row.created_at, updated_at = row.updated_at,
		login_status = row.kind == "openai" and self.openai_login
			and self.openai_login:getState(row.config.auth_path).status or nil}
end

---@return {users: ai.router.PublicUser[]}
function Management:listUsers()
	---@type ai.router.PublicUser[]
	local rows = json.array({})
	for _, row in ipairs(self.users_repo:list()) do table.insert(rows, self:publicUser(row)) end
	return {users = rows}
end

---@return {subscriptions: ai.router.PublicSubscription[]}
function Management:listSubscriptions()
	---@type ai.router.PublicSubscription[]
	local rows = json.array({})
	for _, row in ipairs(self.subscriptions_repo:list()) do table.insert(rows, self:publicSubscription(row)) end
	return {subscriptions = rows}
end

---@return {public_models: string[], aliases: ai.router.ModelRow[]}
function Management:listModels()
	---@type string[]
	local names = json.array({})
	for name in pairs(self.server.router.state.public_models) do table.insert(names, name) end
	table.sort(names)
	return {public_models = names, aliases = json.array(self.models_repo:list())}
end

---@return {now: integer, subscriptions: ai.router.ManagementSubscriptionStatus[], catalog_reload_pending: boolean}
function Management:status()
	---@type ai.router.ManagementSubscriptionStatus[]
	local rows = json.array({})
	for _, row in ipairs(self.subscriptions_repo:list()) do
		table.insert(rows, {id = row.id, name = row.name, enabled = row.enabled,
			windows = self.monitor.windows[row.id] or json.object({}),
			cooldown_until = self.server.cooldowns[row.id],
			login_status = row.kind == "openai" and self.openai_login
				and self.openai_login:getState(row.config.auth_path).status or nil})
	end
	return {now = self.get_time(), subscriptions = rows, catalog_reload_pending = self.catalog_reload_pending}
end

---@param args {[string]: any}
---@return {hours: integer, rows: ai.router.UsageRow[]}
function Management:usage(args)
	local history = self.usage_repo:history(self.get_time())
	---@type ai.router.UsageRow[]
	local rows = json.array({})
	local since = self.get_time() - (args.hours or 24) * 3600
	for _, row in ipairs(history.rows) do
		if row.bucket >= since then table.insert(rows, row) end
	end
	return {hours = args.hours or 24, rows = rows}
end

---@param id integer
---@return ai.router.SubscriptionRow
function Management:editableSubscription(id)
	local row = self.subscriptions_repo:get(id)
	check(row, "Subscription not found.")
	if row.kind == "openai" and self.openai_login then
		check(not self.openai_login:isLoggingIn(row.config.auth_path), "Wait for the OpenAI login to finish before editing or deleting this subscription.")
	end
	return row
end

---@param args {[string]: any}
---@return {user: ai.router.PublicUser, api_key: string}
function Management:createUser(args)
	checkName(args.name, "User")
	checkGrants(args.models)
	check(not self.users_repo:findByName(args.name), "User name already exists.")
	local user, key = self.users_repo:create(args.name, self.get_time())
	self.users_repo:setGrants(user.id, args.models)
	return {user = self:publicUser(user), api_key = key}
end

---@param args {[string]: any}
---@return {user: ai.router.PublicUser}
function Management:updateUser(args)
	check(self.users_repo:get(args.id), "User not found.")
	if args.name then
		checkName(args.name, "User")
		local existing = self.users_repo:findByName(args.name)
		check(not existing or existing.id == args.id, "User name already exists.")
	end
	if args.models then checkGrants(args.models) end
	local user = self.users_repo:update(args.id, {name = args.name, disabled = args.disabled,
		max_concurrency = args.max_concurrency, max_rpm = args.max_rpm}, self.get_time())
	if args.models then self.users_repo:setGrants(args.id, args.models) end
	return {user = self:publicUser(user)}
end

---@param args {[string]: any}
---@return {id: integer, api_key: string}
function Management:regenerateKey(args)
	check(self.users_repo:get(args.id), "User not found.")
	return {id = args.id, api_key = self.users_repo:regenerateKey(args.id, self.get_time())}
end

---@param args {[string]: any}
---@return {deleted_id: integer}
function Management:deleteUser(args)
	check(self.users_repo:get(args.id), "User not found.")
	self.users_repo:delete(args.id)
	return {deleted_id = args.id}
end

---@param args {[string]: any}
---@return {subscription: ai.router.PublicSubscription}
function Management:saveSubscription(args)
	local existing = args.id and self:editableSubscription(args.id)
	local config = args.config or (existing and existing.config)
	local kind = args.kind or (existing and existing.kind)
	if not existing and kind == "openai" and config and not config.auth_path then
		config.auth_path = "userdata/ai_router_auth_" .. random.hex(16) .. ".lua"
	end
	-- Config updates are patches, allowing edits without reading stored credentials.
	if existing and args.config then
		config = {}
		if kind == existing.kind then
			for key, value in pairs(existing.config) do config[key] = value end
		end
		for key, value in pairs(args.config) do config[key] = value end
	end
	local row = {id = args.id or -1, name = args.name or (existing and existing.name),
		kind = kind, config = config, limits = args.limits or (existing and existing.limits) or {},
		priority = args.priority or (existing and existing.priority), enabled = args.enabled,
		created_at = existing and existing.created_at or self.get_time(), updated_at = self.get_time()}
	if row.enabled == nil then row.enabled = not existing or existing.enabled end
	check(type(row.name) == "string" and #row.name >= 1 and #row.name <= 64, "Subscription name must be 1-64 characters.")
	check(row.kind and row.config and row.priority, "Creating a subscription requires name, kind, priority, and config.")
	local duplicate = self.subscriptions_repo:findByName(row.name)
	check(not duplicate or duplicate.id == args.id, "Subscription name already exists.")
	validateCatalog(replace(self.subscriptions_repo:list(), args.id, row), self.models_repo:list())
	local saved
	if existing then
		saved = self.subscriptions_repo:update(args.id, row, self.get_time())
	else
		saved = self.subscriptions_repo:create(row.name, row.kind, row.priority, row.config, row.limits, self.get_time())
		if not row.enabled then saved = self.subscriptions_repo:update(saved.id, {enabled = false}, self.get_time()) end
	end
	return {subscription = self:publicSubscription(saved)}
end

---@param args {[string]: any}
---@return {deleted_id: integer}
function Management:deleteSubscription(args)
	self:editableSubscription(args.id)
	validateCatalog(replace(self.subscriptions_repo:list(), args.id), self.models_repo:list())
	self.subscriptions_repo:delete(args.id)
	return {deleted_id = args.id}
end

---@param args {[string]: any}
---@return {model: ai.router.ModelRow}
function Management:saveModel(args)
	local existing = args.id and self.models_repo:get(args.id)
	check(not args.id or existing, "Model not found.")
	local row = {id = args.id or -1, name = args.name or (existing and existing.name),
		target = args.target or (existing and existing.target), description = args.description or (existing and existing.description),
		created_at = self.get_time(), updated_at = self.get_time()}
	check(row.name and row.target, "Creating an alias requires name and target.")
	local duplicate = self.models_repo:findByName(row.name)
	check(not duplicate or duplicate.id == args.id, "Model name already exists.")
	validateCatalog(self.subscriptions_repo:list(), replace(self.models_repo:list(), args.id, row))
	local saved = existing and self.models_repo:update(args.id, row, self.get_time())
		or self.models_repo:create(row.name, row.target, row.description, self.get_time())
	return {model = saved}
end

---@param args {[string]: any}
---@return {deleted_id: integer}
function Management:deleteModel(args)
	check(self.models_repo:get(args.id), "Model not found.")
	self.models_repo:delete(args.id)
	return {deleted_id = args.id}
end

---@param args {[string]: any}
---@return {id: integer, login: ai.router.OpenAILoginState}
function Management:loginStatus(args)
	local row = self.subscriptions_repo:get(args.id)
	check(row and row.kind == "openai", "An OpenAI subscription is required.")
	check(self.openai_login, "OpenAI login is unavailable.")
	return {id = args.id, login = self.openai_login:getState(row.config.auth_path)}
end

---@param args {[string]: any}
---@return {id: integer, login: ai.router.OpenAILoginState}
function Management:startLogin(args)
	self:loginStatus(args)
	local row = self:editableSubscription(args.id)
	self.openai_login:start(row)
	return self:loginStatus(args)
end

---@param args {[string]: any}
---@return {scheduled_id: integer}
function Management:refreshUsage(args)
	check(self.subscriptions_repo:get(args.id), "Subscription not found.")
	self.monitor:refresh(args.id)
	return {scheduled_id = args.id}
end

-- Retry runtime application without replaying a persisted mutation.
---@return ai.router.ManagementReloadResult
function Management:reloadCatalog()
	local ok = pcall(function()
		self.server:reload(self.subscriptions_repo:list(), self.models_repo:list())
	end)
	self.catalog_reload_pending = not ok
	return {operation = {persistence = "not_attempted", reload = ok and "applied" or "failed"},
		error = not ok and reload_error or nil}
end

-- Mutations never yield while a transaction is open. OAuth starts outside it.
---@param method string
---@param args {[string]: any}
---@param mutation boolean
---@return ai.router.ManagementResult
---@return string?
function Management:execute(method, args, mutation)
	local orm = self.users_repo.models.router_users.orm
	local begun = false
	local ok, result = pcall(function()
		if mutation then orm:begin("immediate") begun = true end
		local value = self[method](self, args)
		if mutation then orm:commit() begun = false end
		return value
	end)
	if not ok then
		local rolled_back = not begun or pcall(orm.db.exec, orm.db, "ROLLBACK")
		local message = type(result) == "table" and result.management_error or "Operation failed; no credentials or internal error details are exposed."
		if not rolled_back then message = "Persistence state is unknown after rollback failure. Inspect saved data before retrying." end
		return {error = message, operation = mutation and {
			persistence = rolled_back and "not_committed" or "unknown", reload = "not_attempted",
		} or nil}, message
	end
	if mutation then
		---@type ai.router.ManagementOperation
		local operation = {persistence = "committed", reload = "not_required"}
		result.operation = operation
		if catalog_mutations[method] then
			local applied = self:reloadCatalog()
			operation.reload = applied.operation.reload
			result.error = applied.error
		end
	end
	return result, result.error
end

return Management
