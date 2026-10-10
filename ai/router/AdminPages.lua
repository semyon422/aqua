local class = require("class")
local json = require("web.json")
local etlua = require("web.etlua")
local io_util = require("io_util")
local http_util = require("web.http.util")
local Sessions = require("web.framework.Sessions")
local Catalog = require("ai.router.Catalog")

-- Password-protected admin panel: users, subscriptions, custom models,
-- usage statistics, and live status. Server-rendered etlua, HMAC stateless
-- sessions with CSRF protection, and immediate router reloads after every
-- persisted change. Form mutations render the page again on validation
-- errors; successful updates redirect (POST-redirect-get).
---@class ai.router.AdminPages
---@operator call: ai.router.AdminPages
---@field users_repo ai.router.UsersRepo
---@field subscriptions_repo ai.router.SubscriptionsRepo
---@field models_repo ai.router.ModelsRepo
---@field usage_repo ai.router.UsageRepo
---@field monitor ai.router.UsageMonitor
---@field server ai.router.Server
---@field sessions web.Sessions
---@field password string
---@field templates {[string]: fun(env: table?): string}
---@field reload_callback fun()?
---@field get_time fun(): number
local AdminPages = class()

AdminPages.session_seconds = 12 * 3600

---@class ai.router.AdminPagesOptions
---@field users_repo ai.router.UsersRepo
---@field subscriptions_repo ai.router.SubscriptionsRepo
---@field models_repo ai.router.ModelsRepo
---@field usage_repo ai.router.UsageRepo
---@field monitor ai.router.UsageMonitor
---@field server ai.router.Server
---@field password string
---@field get_time (fun(): number)?

---@param options ai.router.AdminPagesOptions
function AdminPages:new(options)
	assert(type(options.password) == "string" and #options.password >= 16,
		"admin password must contain at least 16 characters")
	self.users_repo = options.users_repo
	self.subscriptions_repo = options.subscriptions_repo
	self.models_repo = options.models_repo
	self.usage_repo = options.usage_repo
	self.monitor = options.monitor
	self.server = options.server
	self.password = options.password
	self.get_time = options.get_time or os.time
	self.sessions = Sessions("router_admin", options.password, false)
	self.templates = {}
	for _, name in ipairs({"layout", "login", "users", "subscriptions", "models", "usage", "status"}) do
		local content = io_util.read_file("aqua/ai/router/admin/" .. name .. ".etlua")
		self.templates[name] = etlua.compile(content, "@" .. name)
	end
end

-- Injected by the entrypoint: rebuilds catalog, providers, and monitor.
---@param callback fun()
function AdminPages:setReloadCallback(callback)
	self.reload_callback = callback
end

--- Rebuilds router state after persisted admin mutations.
function AdminPages:reload()
	if self.reload_callback then
		self.reload_callback()
	end
end

---@return ai.router.SubscriptionRow[]
function AdminPages:getSubscriptionRows()
	return self.subscriptions_repo:list()
end

---@return ai.router.ModelRow[]
function AdminPages:getModelRows()
	return self.models_repo:list()
end

---@param res web.Response
---@param status integer
---@param html string
local function send(res, status, html)
	res.status = status
	res.headers:set("Content-Type", "text/html; charset=utf-8")
	res:set_length(#html)
	res:send(html)
end

---@param res web.Response
---@param location string
local function redirect(res, location)
	res.status = 303
	res.headers:set("Location", location)
	res:set_length(0)
	res:send("")
end

---@param title string
---@param message string
---@return string
local function messageHtml(title, message)
	return ("<!doctype html><html><head><meta charset=\"utf-8\"><title>%s</title></head><body><h1>%s</h1><p>%s</p><p><a href=\"/admin\">Sign in</a></p></body></html>")
		:format(etlua.html_escape(title), etlua.html_escape(title), etlua.html_escape(message))
end

---@param message string
---@return string
local function renderError(message)
	return ('<div class="error">%s</div>'):format(etlua.html_escape(message))
end


---@param title string
---@param session {csrf_token: string}
---@param content string
---@return string
local function page(templates, title, session, content)
	return templates.layout({
		title = title,
		content = content,
		csrf_token = session.csrf_token,
	})
end

-- Handles an /admin/* request. Returns false when the path is not admin.
---@param req web.Request
---@param res web.Response
---@return boolean handled
function AdminPages:handle(req, res)
	local path = req.uri:match("^[^?]+") or req.uri
	if path ~= "/admin" and not path:match("^/admin/") then
		return false
	end
	local method = req.method
	if path == "/admin" or path == "/admin/login" then
		if method == "POST" then
			self:login(req, res)
		else
			self:renderLogin(res, nil)
		end
		return true
	end
	local session = self:session(req)
	if not session then
		if method == "POST" then
			send(res, 403, messageHtml("Forbidden", "Session expired. Sign in again."))
		else
			redirect(res, "/admin")
		end
		return true
	end
	if method == "POST" and path == "/admin/logout" then
		self:logout(res)
		return true
	end
	---@type {[string]: fun(self: ai.router.AdminPages, req: web.Request, res: web.Response, session: table, query: {[string]: string})}
	local pages = {
		["/admin/users"] = self.pageUsers,
		["/admin/subscriptions"] = self.pageSubscriptions,
		["/admin/models"] = self.pageModels,
		["/admin/usage"] = self.pageUsage,
		["/admin/status"] = self.pageStatus,
	}
	local mutations = {
		["/admin/users/create"] = self.createUser,
		["/admin/users/update"] = self.updateUser,
		["/admin/users/grants"] = self.updateGrants,
		["/admin/users/regenerate"] = self.regenerateKey,
		["/admin/users/delete"] = self.deleteUser,
		["/admin/subscriptions/save"] = self.saveSubscription,
		["/admin/subscriptions/delete"] = self.deleteSubscription,
		["/admin/models/save"] = self.saveModel,
		["/admin/models/delete"] = self.deleteModel,
	}
	if method == "GET" and pages[path] then
		local query = self:query(req)
		pages[path](self, res, session, query)
	elseif method == "POST" and mutations[path] then
		self:mutation(mutations[path], req, res, session)
	else
		send(res, 404, messageHtml("Not found", "Unknown admin page."))
	end
	return true
end

-- Parses the form, validates CSRF, runs the mutation inside pcall, and
-- converts a raised error into a rendered 400 page. Mutations render or
-- redirect themselves.
---@param mutation fun(self: ai.router.AdminPages, res: web.Response, session: table, form: {[string]: any})
---@param req web.Request
---@param res web.Response
---@param session {csrf_token: string}
function AdminPages:mutation(mutation, req, res, session)
	local form = http_util.get_form(req) or {}
	---@cast form {[string]: any}
	if not self.sessions:validate_csrf_token(session, form.csrf_token) then
		send(res, 403, messageHtml("Forbidden", "Invalid CSRF token."))
		return
	end
	local ok, err = pcall(function()
		mutation(self, res, session, form)
	end)
	if not ok then
		send(res, 400, page(self.templates, "Error", session, renderError(tostring(err))))
	end
end

-- Session and auth -----------------------------------------------------------

---@param req web.Request
---@return table?
function AdminPages:session(req)
	local session = self.sessions:get(req.headers)
	if not session then return nil end
	if not session.expires or session.expires < self.get_time() then return nil end
	return session
end

---@param req web.Request
---@param res web.Response
function AdminPages:login(req, res)
	local form = http_util.get_form(req) or {}
	---@cast form {[string]: any}
	if form.password ~= self.password then
		self:renderLogin(res, "Invalid password.")
		return
	end
	self.sessions:set(res.headers, {expires = self.get_time() + AdminPages.session_seconds})
	redirect(res, "/admin/users")
end

---@param res web.Response
function AdminPages:logout(res)
	res.headers:add("Set-Cookie", "router_admin=; Path=/; Max-Age=0")
	redirect(res, "/admin")
end

-- Parsing helpers ------------------------------------------------------------

---@param req web.Request
---@return {[string]: string}
function AdminPages:query(req)
	local query_string = req.uri:match("%?(.+)$") or ""
	return http_util.decode_query_string(query_string)
end

---@param value any
---@return string
local function assertName(value)
	assert(type(value) == "string" and #value >= 1 and #value <= 64, "name is required (1-64 characters)")
	return value
end

---@param value any
---@return integer
local function assertId(value)
	local id = tonumber(value)
	assert(id and id % 1 == 0, "invalid id")
	return id
end

---@param value any
---@return string
local function assertKind(value)
	assert(value == "openai" or value == "zai" or value == "openai_compat",
		"kind must be openai, zai, or openai_compat")
	return value
end

---@param value any
---@return integer
local function assertPriority(value)
	local priority = tonumber(value)
	assert(priority and priority % 1 == 0, "priority must be an integer")
	return priority
end

-- Collects granted models from a newline-separated textarea.
---@param value any
---@return string[]
local function formModelList(value)
	local list = {}
	for model in tostring(value or ""):gmatch("[^\n]+") do
		model = model:match("^%s*(.-)%s*$")
		if model ~= "" then table.insert(list, model) end
	end
	return list
end

---@param value any
---@param label string
---@return table
local function decodeObject(value, label)
	assert(type(value) == "string" and value ~= "", label .. " JSON is required")
	local decoded = json.decode_safe(value)
	assert(type(decoded) == "table", label .. " must be a JSON object")
	---@cast decoded {[string]: any}
	return decoded
end

-- Aggregates history rows into totals plus per-dimension tables.
---@param rows any[]
---@return ai.router.UsageTotals totals
---@return {[string]: ai.router.UsageTotals} by_user
---@return {[string]: ai.router.UsageTotals} by_model
---@return {[string]: ai.router.UsageTotals} by_subscription
local function aggregate(rows)
	local function bucket()
		return {requests = 0, errors = 0, input_tokens = 0, output_tokens = 0,
			cached_input_tokens = 0, estimated_requests = 0, cost_usd = 0}
	end
	local totals = bucket()
	---@type {[string]: ai.router.UsageTotals}
	local by_user, by_model, by_subscription = {}, {}, {}
	---@param table_ {[string]: ai.router.UsageTotals}
	---@param key string
	---@param row ai.router.UsageRow
	local function addEntry(table_, key, row)
		local item = table_[key]
		if not item then
			item = bucket()
			table_[key] = item
		end
		item.requests = item.requests + row.requests
		item.errors = item.errors + row.errors
		item.input_tokens = item.input_tokens + row.input_tokens
		item.output_tokens = item.output_tokens + row.output_tokens
		item.cached_input_tokens = item.cached_input_tokens + row.cached_input_tokens
		item.estimated_requests = item.estimated_requests + row.estimated_requests
		item.cost_usd = item.cost_usd + row.cost_usd
	end
	for _, row in ipairs(rows) do
		totals.requests = totals.requests + row.requests
		totals.errors = totals.errors + row.errors
		totals.input_tokens = totals.input_tokens + row.input_tokens
		totals.output_tokens = totals.output_tokens + row.output_tokens
		totals.cached_input_tokens = totals.cached_input_tokens + row.cached_input_tokens
		totals.estimated_requests = totals.estimated_requests + row.estimated_requests
		totals.cost_usd = totals.cost_usd + row.cost_usd
		addEntry(by_user, row.user, row)
		addEntry(by_model, row.model, row)
		addEntry(by_subscription, row.subscription, row)
	end
	return totals, by_user, by_model, by_subscription
end

---@param items {[string]: ai.router.UsageTotals}
---@return {key: string, item: ai.router.UsageTotals}[]
local function sortedSection(items)
	---@type string[]
	local keys = {}
	for key in pairs(items) do
		table.insert(keys, key)
	end
	table.sort(keys, function(a, b)
		return items[a].requests > items[b].requests
	end)
	---@type {key: string, item: ai.router.UsageTotals}[]
	local rows = {}
	for i, key in ipairs(keys) do
		rows[i] = {key = key, item = items[key]}
	end
	return rows
end

-- Rendering -------------------------------------------------------------------

---@param res web.Response
---@param error_message string?
function AdminPages:renderLogin(res, error_message)
	local html = self.templates.login({error_message = error_message})
	send(res, error_message and 401 or 200, html)
end

---@return string[]
function AdminPages:publicModelNames()
	local names = {}
	for name in pairs(self.server.router.state.public_models) do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

---@param res web.Response
---@param session {csrf_token: string}
---@param query {[string]: string}
function AdminPages:pageUsers(res, session, query)
	local new_key = query.key
	---@type {[integer]: string[]}
	local grants_by_user = {}
	for _, user in ipairs(self.users_repo:list()) do
		grants_by_user[user.id] = self.users_repo:getGrants(user.id)
	end
	---@type string
	local content = self.templates.users({
		users = self.users_repo:list(),
		grants_by_user = grants_by_user,
		all_models = self:publicModelNames(),
		new_key = new_key,
		error_message = query.error,
		csrf_token = session.csrf_token,
	})
	send(res, query.error and 200 or 200, page(self.templates, "Users", session, content))
end

---@param res web.Response
---@param session {csrf_token: string}
---@param query {[string]: string}
function AdminPages:pageSubscriptions(res, session, query)
	---@type string
	local content = self.templates.subscriptions({
		rows = self:getSubscriptionRows(),
		window_states = self.monitor.windows,
		now = self.get_time(),
		saved_name = query.saved,
		error_message = query.error,
		csrf_token = session.csrf_token,
	})
	send(res, 200, page(self.templates, "Subscriptions", session, content))
end

---@param res web.Response
---@param session {csrf_token: string}
---@param query {[string]: string}
function AdminPages:pageModels(res, session, query)
	---@type string
	local content = self.templates.models({
		rows = self:getModelRows(),
		error_message = query.error,
		csrf_token = session.csrf_token,
	})
	send(res, 200, page(self.templates, "Models", session, content))
end

---@param res web.Response
---@param session {csrf_token: string}
---@param query {[string]: string}
function AdminPages:pageUsage(res, session, query)
	local hours = 24
	if query.hours == "168" then hours = 168 end
	local totals, by_user, by_model, by_subscription = aggregate(self.usage_repo:history(self.get_time()).rows)
	---@type string
	local content = self.templates.usage({
		hours = hours,
		totals = totals,
		sections = {
			{title = "By user", rows = sortedSection(by_user)},
			{title = "By model", rows = sortedSection(by_model)},
			{title = "By subscription", rows = sortedSection(by_subscription)},
		},
		csrf_token = session.csrf_token,
	})
	send(res, 200, page(self.templates, "Usage", session, content))
end

---@param res web.Response
---@param session {csrf_token: string}
function AdminPages:pageStatus(res, session)
	---@type string
	local content = self.templates.status({
		subscriptions = self.server.router.state.subscriptions,
		windows = self.monitor.windows,
		now = self.get_time(),
		csrf_token = session.csrf_token,
	})
	send(res, 200, page(self.templates, "Status", session, content))
end

-- Mutations -------------------------------------------------------------------

---@param res web.Response
---@param session {csrf_token: string}
---@param form {[string]: any}
function AdminPages:createUser(res, session, form)
	local user, key = self.users_repo:create(assertName(form.name), self.get_time())
	self.users_repo:setGrants(user.id, formModelList(form.models))
	self:reload()
	self:renderUsersPage(res, session, key)
end

---@return {[integer]: string[]}
function AdminPages:getGrantsByUser()
	---@type {[integer]: string[]}
	local grants_by_user = {}
	for _, user in ipairs(self.users_repo:list()) do
		grants_by_user[user.id] = self.users_repo:getGrants(user.id)
	end
	return grants_by_user
end

-- Renders the users page after a key reveal mutation.
---@param res web.Response
---@param session {csrf_token: string}
---@param new_key string?
function AdminPages:renderUsersPage(res, session, new_key)
	send(res, 200, page(self.templates, "Users", session, self.templates.users({
		users = self.users_repo:list(),
		grants_by_user = self:getGrantsByUser(),
		all_models = self:publicModelNames(),
		new_key = new_key,
		error_message = nil,
		csrf_token = session.csrf_token,
	})))
end

---@param res web.Response
---@param form {[string]: any}
function AdminPages:updateUser(res, _session, form)
	local changes = {}
	if form.name ~= nil and form.name ~= "" then changes.name = assertName(form.name) end
	changes.disabled = form.disabled == "on" or form.disabled == "1"
	self.users_repo:update(assertId(form.id), changes, self.get_time())
	self:reload()
	redirect(res, "/admin/users")
end

---@param res web.Response
---@param form {[string]: any}
function AdminPages:updateGrants(res, _session, form)
	self.users_repo:setGrants(assertId(form.id), formModelList(form.models))
	self:reload()
	redirect(res, "/admin/users")
end

---@param res web.Response
---@param session {csrf_token: string}
---@param form {[string]: any}
function AdminPages:regenerateKey(res, session, form)
	local key = self.users_repo:regenerateKey(assertId(form.id), self.get_time())
	self:renderUsersPage(res, session, key)
end

---@param res web.Response
---@param form {[string]: any}
function AdminPages:deleteUser(res, _session, form)
	self.users_repo:delete(assertId(form.id))
	self:reload()
	redirect(res, "/admin/users")
end

---@param self ai.router.AdminPages
---@param row ai.router.SubscriptionRow
---@return ai.router.SubscriptionRow[]
local function hypotheticalSubscriptionRows(self, row)
	---@type ai.router.SubscriptionRow[]
	local replaced = {}
	local found = false
	for _, existing in ipairs(self:getSubscriptionRows()) do
		if row.id ~= nil and existing.id == row.id then
			table.insert(replaced, row)
			found = true
		else
			table.insert(replaced, existing)
		end
	end
	if not found then table.insert(replaced, row) end
	return replaced
end

---@param res web.Response
---@param session {csrf_token: string}
---@param form {[string]: any}
function AdminPages:saveSubscription(res, session, form)
	local config = decodeObject(form.config, "config")
	local limits = decodeObject(form.limits, "limits")
	local name = assertName(form.name)
	local kind = assertKind(form.kind)
	local priority = assertPriority(form.priority)
	local enabled = form.enabled == "on" or form.enabled == "1"
	local id = form.id ~= nil and form.id ~= "" and assertId(form.id) or nil
	local now = self.get_time()
	-- Validate the whole hypothetical catalog before persisting anything.
	local _, errors = Catalog.fromRows(hypotheticalSubscriptionRows(self, {
		id = id or -1,
		name = name,
		kind = kind,
		priority = priority,
		enabled = enabled,
		config = config,
		limits = limits,
		created_at = now,
		updated_at = now,
	}), self:getModelRows())
	if #errors > 0 then
		self:pageSubscriptions(res, session, {error = "catalog validation failed:\n" .. table.concat(errors, "\n")})
		return
	end
	if id then
		self.subscriptions_repo:update(id, {
			name = name, kind = kind, priority = priority, enabled = enabled,
			config = config, limits = limits,
		}, now)
	else
		self.subscriptions_repo:create(name, kind, priority, config, limits, now)
	end
	self:reload()
	self:pageSubscriptions(res, session, {saved = name})
end

---@param res web.Response
---@param session {csrf_token: string}
---@param form {[string]: any}
function AdminPages:deleteSubscription(res, session, form)
	local id = assertId(form.id)
	-- Deleting a subscription can break alias chains: validate the hypothetical
	-- catalog without the row before persisting.
	---@type ai.router.SubscriptionRow[]
	local remaining = {}
	for _, existing in ipairs(self:getSubscriptionRows()) do
		if existing.id ~= id then
			table.insert(remaining, existing)
		end
	end
	local _, errors = Catalog.fromRows(remaining, self:getModelRows())
	if #errors > 0 then
		self:pageSubscriptions(res, session, {error = "cannot delete: catalog validation failed:\n"
			.. table.concat(errors, "\n")})
		return
	end
	self.subscriptions_repo:delete(id)
	self:reload()
	redirect(res, "/admin/subscriptions")
end

-- Validates the hypothetical model state before persisting.
---@param self ai.router.AdminPages
---@param row ai.router.ModelRow
---@return string[] errors
local function hypotheticalModelErrors(self, row)
	---@type ai.router.ModelRow[]
	local replaced = {}
	local found = false
	for _, existing in ipairs(self:getModelRows()) do
		if row.id ~= nil and existing.id == row.id then
			table.insert(replaced, row)
			found = true
		else
			table.insert(replaced, existing)
		end
	end
	if not found then table.insert(replaced, row) end
	local _, errors = Catalog.fromRows(self:getSubscriptionRows(), replaced)
	return errors
end

---@param res web.Response
---@param session {csrf_token: string}
---@param form {[string]: any}
function AdminPages:saveModel(res, session, form)
	local chain_list = formModelList(form.chain)
	local description = form.description ~= "" and form.description or nil
	local name = assertName(form.name)
	local now = self.get_time()
	local id = form.id ~= nil and form.id ~= "" and assertId(form.id) or nil
	local errors = hypotheticalModelErrors(self, {
		id = id or -1,
		name = name,
		chain = chain_list,
		description = description,
		created_at = now,
		updated_at = now,
	})
	if #errors > 0 then
		self:pageModels(res, session, {error = "catalog validation failed:\n" .. table.concat(errors, "\n")})
		return
	end
	if id then
		self.models_repo:update(id, {
			name = name, chain = chain_list, description = description,
		}, now)
	else
		self.models_repo:create(name, chain_list, description, now)
	end
	self:reload()
	redirect(res, "/admin/models")
end

---@param res web.Response
---@param form {[string]: any}
function AdminPages:deleteModel(res, _session, form)
	self.models_repo:delete(assertId(form.id))
	self:reload()
	redirect(res, "/admin/models")
end

---@class ai.router.UsageTotals
---@field requests integer
---@field errors integer
---@field input_tokens integer
---@field output_tokens integer
---@field cached_input_tokens integer
---@field estimated_requests integer
---@field cost_usd number

return AdminPages
