local class = require("class")
local json = require("web.json")
local OAuthRepo = require("ai.router.OAuthRepo")
local Catalog = require("ai.router.Catalog")
local Provider = require("ai.router.Provider")
local RequestMetrics = require("ai.router.RequestMetrics")

---@class ai.router.ManagementOptions
---@field users_repo ai.router.UsersRepo
---@field channels_repo ai.router.ChannelsRepo
---@field models_repo ai.router.ModelsRepo
---@field usage_repo ai.router.UsageRepo
---@field monitor ai.router.UsageMonitor
---@field server ai.router.Server
---@field openai_login ai.router.OpenAILoginManager?
---@field get_time (fun(): integer)?

---@class ai.router.Management: ai.router.ManagementOptions
---@operator call: ai.router.Management
---@field catalog_reload_pending boolean
---@field active_probes {[integer]: boolean}
---@field oauth_repo ai.router.OAuthRepo
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

---@class ai.router.PublicChannelConfig
---@field models string[]?
---@field model_redirects {[string]: string}?
---@field base_url string?
---@field usage_url string?
---@field reasoning_effort "none"|"low"|"medium"|"high"?
---@field verbosity "low"|"medium"|"high"?
---@field max_response_size integer?
---@field thinking "enabled"|"disabled"?
---@field tool_stream boolean?

---@class ai.router.PublicChannelLimits
---@field five_hour_quota_tokens integer?
---@field weekly_quota_tokens integer?
---@field poll_interval integer?
---@field usage_source {five_hour: ("local"|"upstream")?, weekly: ("local"|"upstream")?}?

---@class ai.router.PublicChannel
---@field id integer
---@field name string
---@field kind "openai"|"zai"|"openai_compat"
---@field enabled boolean
---@field config ai.router.PublicChannelConfig
---@field limits ai.router.PublicChannelLimits
---@field has_api_key boolean
---@field created_at integer
---@field updated_at integer
---@field login_status openai.SubscriptionAuthStatus?

---@class ai.router.ManagementChannelStatus
---@field id integer
---@field name string
---@field enabled boolean
---@field windows {five_hour: ai.router.WindowSnapshot?, weekly: ai.router.WindowSnapshot?}
---@field usage_poll ai.router.UsagePollStatus?
---@field login_status openai.SubscriptionAuthStatus?

---@class ai.router.ManagementResultMetadata
---@field operation ai.router.ManagementOperation?
---@field error string?

---@class ai.router.ManagementResult: ai.router.ManagementResultMetadata
---@field users ai.router.PublicUser[]?
---@field channels ai.router.PublicChannel[]|ai.router.ManagementChannelStatus[]?
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
---@field channel ai.router.PublicChannel?
---@field model ai.router.ModelRow?
---@field login ai.router.OpenAILoginState?
---@field scheduled_id integer?
---@field probe ai.router.ChannelProbe?

---@class ai.router.ChannelProbe
---@field id integer
---@field channel string
---@field model string qualified public model
---@field upstream_model string
---@field protocol "responses"|"chat_completions"
---@field ok boolean inference succeeded, not an exact output-content assertion
---@field status integer logical outcome, not necessarily upstream HTTP status
---@field duration_ms integer
---@field error_code ai.router.RequestErrorCode?
---@field input_tokens integer?
---@field output_tokens integer?
---@field cached_input_tokens integer?

---@type {[string]: boolean}
local catalog_mutations = {saveChannel = true, deleteChannel = true, saveModel = true, deleteModel = true}
local reload_error = "Changes are saved, but catalog reload failed. Do not repeat the mutation; call router_reload_catalog to retry applying the saved catalog."

---@param options ai.router.ManagementOptions
function Management:new(options)
	for key, value in pairs(options) do self[key] = value end
	self.get_time = options.get_time or os.time
	self.catalog_reload_pending = false
	self.active_probes = {}
	self.oauth_repo = OAuthRepo(options.channels_repo.models)
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
		check(#model >= 1 and #model <= 193, "Granted model names must be 1-193 characters.")
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

---@param channels ai.router.ChannelRow[]
---@param models ai.router.ModelRow[]
local function validateCatalog(channels, models)
	local _, errors = Catalog.fromRows(channels, models)
	-- Catalog diagnostics may contain operator-supplied values; never reflect them.
	check(#errors == 0, "Invalid catalog: check channel config, limits, redirects, and alias targets.")
end

---@param row ai.router.UserRow
---@return ai.router.PublicUser
function Management:publicUser(row)
	return {id = row.id, name = row.name, key_hint = row.key_hint, disabled = row.disabled,
		max_concurrency = row.max_concurrency, max_rpm = row.max_rpm,
		created_at = row.created_at, updated_at = row.updated_at,
		models = json.array(self.users_repo:getGrants(row.id))}
end

---@param row ai.router.ChannelRow
---@return ai.router.PublicChannel
function Management:publicChannel(row)
	---@type ai.router.PublicChannelConfig
	local config = json.object({})
	for _, key in ipairs({"models", "model_redirects", "base_url", "usage_url",
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
	---@type ai.router.PublicChannelLimits
	local limits = json.object({})
	for key, value in pairs(row.limits) do
		if key == "usage_source" then
			local sources = json.object({})
			for window, source in pairs(value) do sources[window] = source end
			value = sources
		end
		limits[key] = value
	end
	return {id = row.id, name = row.name, kind = row.kind,
		enabled = row.enabled, config = config, limits = limits,
		has_api_key = row.config.api_key ~= nil, created_at = row.created_at, updated_at = row.updated_at,
		login_status = row.kind == "openai" and self.openai_login
			and self.openai_login:getState(row.id).status or nil}
end

---@return {users: ai.router.PublicUser[]}
function Management:listUsers()
	---@type ai.router.PublicUser[]
	local rows = json.array({})
	for _, row in ipairs(self.users_repo:list()) do table.insert(rows, self:publicUser(row)) end
	return {users = rows}
end

---@return {channels: ai.router.PublicChannel[]}
function Management:listChannels()
	---@type ai.router.PublicChannel[]
	local rows = json.array({})
	for _, row in ipairs(self.channels_repo:list()) do table.insert(rows, self:publicChannel(row)) end
	return {channels = rows}
end

---@return {public_models: string[], aliases: ai.router.ModelRow[]}
function Management:listModels()
	---@type string[]
	local names = json.array({})
	for name in pairs(self.server.router.state.public_models) do table.insert(names, name) end
	table.sort(names)
	return {public_models = names, aliases = json.array(self.models_repo:list())}
end

---@return {now: integer, channels: ai.router.ManagementChannelStatus[], catalog_reload_pending: boolean}
function Management:status()
	---@type ai.router.ManagementChannelStatus[]
	local rows = json.array({})
	for _, row in ipairs(self.channels_repo:list()) do
		table.insert(rows, {id = row.id, name = row.name, enabled = row.enabled,
			windows = self.monitor.windows[row.id] or json.object({}),
			usage_poll = self.monitor.poll_status[row.id],
			login_status = row.kind == "openai" and self.openai_login
				and self.openai_login:getState(row.id).status or nil})
	end
	return {now = self.get_time(), channels = rows, catalog_reload_pending = self.catalog_reload_pending}
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
---@return ai.router.ChannelRow
function Management:editableChannel(id)
	local row = self.channels_repo:get(id)
	check(row, "Channel not found.")
	if row.kind == "openai" and self.openai_login then
		check(not self.openai_login:isLoggingIn(row.id), "Wait for the OpenAI login to finish before editing or deleting this channel.")
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
---@return {channel: ai.router.PublicChannel}
function Management:saveChannel(args)
	local existing = args.id and self:editableChannel(args.id)
	local config = args.config or (existing and existing.config)
	local kind = args.kind or (existing and existing.kind)
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
		enabled = args.enabled,
		created_at = existing and existing.created_at or self.get_time(), updated_at = self.get_time()}
	if row.enabled == nil then row.enabled = not existing or existing.enabled end
	check(type(row.name) == "string" and #row.name >= 1 and #row.name <= 64, "Channel name must be 1-64 characters.")
	check(row.kind and row.config, "Creating a channel requires name, kind, and config.")
	local duplicate = self.channels_repo:findByName(row.name)
	check(not duplicate or duplicate.id == args.id, "Channel name already exists.")
	validateCatalog(replace(self.channels_repo:list(), args.id, row), self.models_repo:list())
	local saved
	if existing then
		saved = self.channels_repo:update(args.id, row, self.get_time())
	else
		saved = self.channels_repo:create(row.name, row.kind, row.config, row.limits, self.get_time())
		if not row.enabled then saved = self.channels_repo:update(saved.id, {enabled = false}, self.get_time()) end
	end
	if not existing or existing.kind ~= saved.kind then
		self.oauth_repo:delete(saved.id)
		if saved.kind == "openai" then self.oauth_repo:create(saved.id) end
	end
	return {channel = self:publicChannel(saved)}
end

---@param args {[string]: any}
---@return {deleted_id: integer}
function Management:deleteChannel(args)
	self:editableChannel(args.id)
	validateCatalog(replace(self.channels_repo:list(), args.id), self.models_repo:list())
	self.channels_repo:delete(args.id)
	self.oauth_repo:delete(args.id)
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
	validateCatalog(self.channels_repo:list(), replace(self.models_repo:list(), args.id, row))
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
	local row = self.channels_repo:get(args.id)
	check(row and row.kind == "openai", "An OpenAI channel is required.")
	check(self.openai_login, "OpenAI login is unavailable.")
	return {id = args.id, login = self.openai_login:getState(row.id)}
end

---@param args {[string]: any}
---@return {id: integer, login: ai.router.OpenAILoginState}
function Management:startLogin(args)
	self:loginStatus(args)
	local row = self:editableChannel(args.id)
	self.openai_login:start(row)
	return self:loginStatus(args)
end

---@param args {[string]: any}
---@return {scheduled_id: integer}
function Management:refreshUsage(args)
	check(self.channels_repo:get(args.id), "Channel not found.")
	self.monitor:refresh(args.id)
	return {scheduled_id = args.id}
end

---@param args {id: integer, model: string} unqualified configured model, not an alias
---@return {probe: ai.router.ChannelProbe}
function Management:testChannel(args)
	check(not self.catalog_reload_pending, "Reload the saved catalog before testing a channel.")
	local row = self.channels_repo:get(args.id)
	check(row, "Channel not found.")
	check(row.enabled, "Enable the channel before testing it.")
	if row.kind == "openai" and self.openai_login then
		check(not self.openai_login:isLoggingIn(row.id), "Wait for the OpenAI login to finish before testing this channel.")
	end
	check(not self.active_probes[row.id], "A test is already running for this channel.")
	local public_model = row.name .. "/" .. args.model
	local candidate = self.server.router:resolve(public_model)
	check(candidate and candidate.channel.id == row.id, "Select a configured model on this channel.")
	local provider = self.server.providers[row.id]
	local native = row.kind == "openai"
	check(provider and (native and provider.createResponse or not native and provider.complete), "Channel provider is unavailable.")
	local metrics = RequestMetrics(self.server.get_time)
	self.active_probes[row.id] = true
	local invoked, value, err, provider_error = pcall(function()
		if native then
			return provider:createResponse({model = candidate.model, input = "Reply with exactly OK.",
				store = false, stream = false}, candidate.upstream_model)
		end
		return provider:complete({model = candidate.model, stream = false, max_tokens = 16,
			messages = {{role = "user", content = "Reply with exactly OK."}},
			thinking = row.kind == "zai" and {type = "disabled"} or nil}, candidate.upstream_model)
	end)
	self.active_probes[row.id] = nil
	if not invoked then value, err, provider_error = nil, nil, nil end
	local status = 200
	if type(value) ~= "table" then
		status = 502
		if provider_error and type(provider_error.status) == "number" then status = provider_error.status end
		metrics:providerError(err, provider_error)
	elseif native and value.status == "failed" then
		status = 502
		metrics:providerError(nil, type(value.error) == "table" and value.error or nil)
	end
	---@type ai.router.CanonicalUsage?
	local usage
	if type(value) == "table" then
		if native then usage = Provider.canonicalUsage(value.usage)
		else usage = value.usage end
	end
	return {probe = {id = row.id, channel = row.name, model = public_model,
		upstream_model = candidate.upstream_model, protocol = native and "responses" or "chat_completions",
		ok = status < 400, status = status,
		duration_ms = math.max(0, math.floor((self.server.get_time() - metrics.started_at) * 1000)),
		error_code = metrics:outcomeCode(status), input_tokens = usage and usage.input_tokens,
		output_tokens = usage and usage.output_tokens, cached_input_tokens = usage and usage.cached_input_tokens}}
end

-- Retry runtime application without replaying a persisted mutation.
---@return ai.router.ManagementReloadResult
function Management:reloadCatalog()
	local ok = pcall(function()
		self.server:reload(self.channels_repo:list(), self.models_repo:list())
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
