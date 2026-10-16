local class = require("class")
local etlua = require("web.etlua")
local io_util = require("io_util")
local http_util = require("web.http.util")
local json = require("web.json")
local Sessions = require("web.framework.Sessions")
local UsageDashboardGenerator = require("ai.router.UsageDashboardGenerator")

---@class ai.router.AdminPages: ai.router.AdminPagesOptions
---@operator call: ai.router.AdminPages
---@field sessions web.Sessions
---@field password string
---@field stylesheet string
---@field overview_script string
---@field usage_script string
---@field theme_script string
---@field templates {[string]: fun(env: table?): string}
local AdminPages = class()

AdminPages.session_seconds = 12 * 3600

---@class ai.router.AdminPagesOptions
---@field users_repo ai.router.UsersRepo
---@field channels_repo ai.router.ChannelsRepo
---@field models_repo ai.router.ModelsRepo
---@field usage_repo ai.router.UsageRepo
---@field monitor ai.router.UsageMonitor
---@field server ai.router.Server
---@field openai_login ai.router.OpenAILoginManager?
---@field get_time (fun(): integer)?
---@field password string

---@param options ai.router.AdminPagesOptions
function AdminPages:new(options)
	assert(type(options.password) == "string" and #options.password >= 16, "admin password must contain at least 16 characters")
	self.users_repo = options.users_repo
	self.channels_repo = options.channels_repo
	self.models_repo = options.models_repo
	self.usage_repo = options.usage_repo
	self.monitor = options.monitor
	self.server = options.server
	self.openai_login = options.openai_login
	self.password = options.password
	self.get_time = options.get_time or os.time
	self.sessions = Sessions("router_admin", options.password, false)
	self.stylesheet = io_util.read_file("aqua/ai/router/admin/dashboard.css")
	self.overview_script = io_util.read_file("aqua/ai/router/admin/overview.js")
	self.usage_script = io_util.read_file("aqua/ai/router/admin/usage.js")
	self.theme_script = io_util.read_file("aqua/ai/router/admin/theme.js")
	self.templates = {}
	for _, name in ipairs({"layout", "login", "overview", "users", "channels", "models", "usage", "requests"}) do
		self.templates[name] = etlua.compile(io_util.read_file("aqua/ai/router/admin/" .. name .. ".etlua"), "@" .. name)
	end
end

---@param res web.Response
---@param status integer
---@param html string
local function send(res, status, html)
	res.status = status
	res.headers:set("Content-Type", "text/html; charset=utf-8")
	res.headers:set("Cache-Control", "no-store")
	res:set_length(#html)
	res:send(html)
end

---@param res web.Response
---@param status integer
---@param value {html: string?, now: integer?, error: string?}
local function sendJson(res, status, value)
	local body = json.encode(value)
	res.status = status
	res.headers:set("Content-Type", "application/json; charset=utf-8")
	res.headers:set("Cache-Control", "no-store")
	res:set_length(#body)
	res:send(body)
end

---@param res web.Response
---@param location string
local function redirect(res, location)
	res.status = 303
	res.headers:set("Location", location)
	res.headers:set("Cache-Control", "no-store")
	res:set_length(0)
	res:send("")
end

---@param req web.Request
---@return table?
function AdminPages:session(req)
	local session = self.sessions:get(req.headers)
	if session and session.expires and session.expires >= self.get_time() then return session end
end

---@param req web.Request
---@param res web.Response
---@return boolean
function AdminPages:handle(req, res)
	local path = req.uri:match("^[^?]+") or req.uri
	if path ~= "/admin" and not path:match("^/admin/") then return false end
	if path == "/admin" or path == "/admin/login" then
		if req.method == "POST" and path == "/admin/login" then
			local form = http_util.get_form(req) or {}
			if form.password == self.password then
				self.sessions:set(res.headers, {expires = self.get_time() + self.session_seconds})
				redirect(res, "/admin/overview")
			else
				send(res, 401, self.templates.login({error_message = "Invalid password.", stylesheet = self.stylesheet, theme_script = self.theme_script}))
			end
		elseif req.method == "GET" then
			if path == "/admin" and self:session(req) then
				redirect(res, "/admin/overview")
			else
				send(res, 200, self.templates.login({stylesheet = self.stylesheet, theme_script = self.theme_script}))
			end
		else
			res.headers:set("Allow", "GET")
			send(res, 405, "Read-only dashboard. Manage the router through MCP.")
		end
		return true
	end
	local session = self:session(req)
	if path == "/admin/overview/data" then
		if not session then
			sendJson(res, 401, {error = "Sign in to view the dashboard."})
		elseif req.method ~= "GET" then
			res.headers:set("Allow", "GET")
			sendJson(res, 405, {error = "Read-only dashboard."})
		else
			local view = self:overviewData()
			sendJson(res, 200, {html = self.templates.overview(view), now = view.now})
		end
		return true
	end
	if not session then
		if req.method == "GET" then redirect(res, "/admin")
		else send(res, 403, "Sign in to view the dashboard.") end
		return true
	end
	if req.method == "POST" and path == "/admin/logout" then
		local form = http_util.get_form(req) or {}
		if not self.sessions:validate_csrf_token(session, form.csrf_token) then
			send(res, 403, "Invalid CSRF token.")
		else
			res.headers:add("Set-Cookie", "router_admin=; Path=/; Max-Age=0")
			redirect(res, "/admin")
		end
		return true
	end
	if req.method ~= "GET" then
		res.headers:set("Allow", "GET")
		send(res, 405, "Read-only dashboard. Manage the router through MCP.")
		return true
	end
	local query = http_util.decode_query_string(req.uri:match("%?(.+)$") or "")
	if path == "/admin/subscriptions" or path == "/admin/status" then
		redirect(res, "/admin/channels")
		return true
	end
	local pages = { ["/admin/overview"] = self.pageOverview,
		["/admin/users"] = self.pageUsers, ["/admin/channels"] = self.pageChannels,
		["/admin/models"] = self.pageModels, ["/admin/usage"] = self.pageUsage,
		["/admin/requests"] = self.pageRequests }
	if pages[path] then pages[path](self, res, session, query)
	else send(res, 404, "Unknown admin page.") end
	return true
end

---@param res web.Response
---@param session {csrf_token: string}
---@param title string
---@param content string
function AdminPages:render(res, session, title, content)
	send(res, 200, self.templates.layout({title = title, content = content, csrf_token = session.csrf_token,
		stylesheet = self.stylesheet, theme_script = self.theme_script,
		page_script = title == "Overview" and self.overview_script or title == "Usage" and self.usage_script or ""}))
end

---@class ai.router.OverviewChannel
---@field name string
---@field kind string
---@field enabled boolean
---@field model_count integer
---@field login_status openai.SubscriptionAuthStatus?
---@field windows {[string]: ai.router.WindowSnapshot}
---@field poll ai.router.UsagePollStatus?

---@class ai.router.OverviewData
---@field channels ai.router.OverviewChannel[]
---@field enabled_count integer
---@field model_count integer
---@field user_count integer
---@field now integer

---@return ai.router.OverviewData
function AdminPages:overviewData()
	---@type ai.router.OverviewChannel[]
	local channels = {}
	local enabled = 0
	for _, row in ipairs(self.channels_repo:list()) do
		if row.enabled then enabled = enabled + 1 end
		---@type string[]
		local models = row.config.models
		table.insert(channels, {name = row.name, kind = row.kind, enabled = row.enabled,
			model_count = #models,
			login_status = row.kind == "openai" and self.openai_login
				and self.openai_login:getState(row.id).status or nil,
			windows = self.monitor.windows[row.id] or {}, poll = self.monitor.poll_status[row.id]})
	end
	---@type {[string]: boolean}
	local public_models = self.server.router.state.public_models
	local model_count = 0
	for _ in pairs(public_models) do model_count = model_count + 1 end
	return {channels = channels, enabled_count = enabled, model_count = model_count,
		user_count = #self.users_repo:list(), now = self.get_time()}
end

---@param res web.Response
---@param session {csrf_token: string}
function AdminPages:pageOverview(res, session)
	self:render(res, session, "Overview", self.templates.overview(self:overviewData()))
end

---@param res web.Response
---@param session {csrf_token: string}
function AdminPages:pageUsers(res, session)
	local users = self.users_repo:list()
	---@type {[integer]: string[]}
	local grants = {}
	for _, user in ipairs(users) do grants[user.id] = self.users_repo:getGrants(user.id) end
	self:render(res, session, "Users", self.templates.users({users = users, grants_by_user = grants}))
end

---@param res web.Response
---@param session {csrf_token: string}
function AdminPages:pageChannels(res, session)
	local states = {}
	local rows = self.channels_repo:list()
	if self.openai_login then
		for _, row in ipairs(rows) do
			if row.kind == "openai" then states[row.id] = {status = self.openai_login:getState(row.id).status} end
		end
	end
	self:render(res, session, "Channels", self.templates.channels({rows = rows,
		login_states = states, window_states = self.monitor.windows, poll_states = self.monitor.poll_status, now = self.get_time()}))
end

---@param res web.Response
---@param session {csrf_token: string}
function AdminPages:pageModels(res, session)
	local names = {}
	for name in pairs(self.server.router.state.public_models) do table.insert(names, name) end
	table.sort(names)
	self:render(res, session, "Models", self.templates.models({rows = self.models_repo:list(), public_models = names}))
end

---@param res web.Response
---@param session {csrf_token: string}
---@param query {[string]: string}
function AdminPages:pageUsage(res, session, query)
	local hours = query.hours == "168" and 168 or 24
	local history = self.usage_repo:history(self.get_time())
	self:render(res, session, "Usage", self.templates.usage(UsageDashboardGenerator.generate(history, hours)))
end

---@param res web.Response
---@param session {csrf_token: string}
---@param query {[string]: string}
function AdminPages:pageRequests(res, session, query)
	---@type ai.router.RequestLogFilters
	local filters = {}
	for _, key in ipairs({"user", "model", "channel"}) do
		local value = query[key]
		if value and #value <= 193 and value ~= "" then filters[key] = value end
	end
	if query.outcome == "success" or query.outcome == "error" then filters.outcome = query.outcome end
	local before = tonumber(query.before)
	if before and before >= 1 and before < 2 ^ 53 and before % 1 == 0 then filters.before = before end
	local repo = self.server.request_logs_repo
	local now = self.get_time()
	local rows, next_before = repo:list(filters, now)
	---@type {[string]: string}
	local params = {}
	for _, key in ipairs({"user", "model", "channel", "outcome"}) do
		---@type string?
		local value = filters[key]
		if value then params[key] = value end
	end
	---@param values {[string]: string}
	---@return string
	local function url(values)
		local encoded = http_util.encode_query_string(values)
		return "/admin/requests" .. (encoded ~= "" and "?" .. encoded or "")
	end
	local latest_url = url(params)
	---@type {label: string, value: string, remove_url: string}[]
	local active_filters = {}
	for _, key in ipairs({"user", "channel", "model", "outcome"}) do
		local value = params[key]
		if value then
			params[key] = nil
			table.insert(active_filters, {label = key, value = value, remove_url = url(params)})
			params[key] = value
		end
	end
	---@type string?
	local older_url
	if next_before then
		params.before = tostring(next_before)
		older_url = url(params)
	end
	self:render(res, session, "Requests", self.templates.requests({rows = rows, filters = filters,
		options = repo:filterOptions(now), active_filters = active_filters, latest_url = latest_url,
		older_url = older_url, max_rows = repo.max_rows, page_size = repo.page_size, retention_days = repo.retention_seconds / 86400}))
end

return AdminPages
