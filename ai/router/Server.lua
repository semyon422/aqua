local class = require("class")
local digest = require("digest")
local json = require("web.json")
local random = require("web.random")
---@type {gettime: fun(): number}
local socket = require("socket")
local HttpServer = require("web.http.Server")
local Catalog = require("ai.router.Catalog")
local Router = require("ai.router.Router")
local Provider = require("ai.router.Provider")
local ResponsesProtocol = require("ai.openai.ResponsesProtocol")

-- The authenticated OpenAI-compatible router endpoint. Resolves public
-- models through ai.router.Router, walks candidates with pre-output
-- failover, relays native Responses or Chat Completions results, and
-- records hourly usage aggregates. Nothing downstream is committed before
-- the first upstream output byte, so failed walks return real HTTP errors.
---@class ai.router.Server
---@operator call: ai.router.Server
---@field users_repo ai.router.UsersRepo
---@field usage_repo ai.router.UsageRepo
---@field monitor ai.router.UsageMonitor
---@field router ai.router.Router
---@field providers {[integer]: ai.router.ProviderMethods}
---@field catalog_errors string[]
---@field cooldowns {[integer]: number}
---@field logger fun(line: string)
---@field get_time fun(): number
---@field max_body_size integer
---@field max_concurrent_requests_per_user integer
---@field max_requests_per_minute integer
---@field active_requests {[string]: integer}
---@field request_windows {[string]: {started_at: number, count: integer}}
---@field cooldown_seconds number
---@field admin_handler (fun(req: web.Request, res: web.Response): boolean?)?
---@field http_server web.HttpServer
local Server = class()

Server.max_body_size = 16 * 1024 * 1024
Server.max_clients = 64
Server.max_concurrent_requests_per_user = 4
Server.max_requests_per_minute = 120
Server.cooldown_seconds = 600

-- The provider methods the server calls; implemented by OpenAIProvider,
-- ZaiProvider, and CompatProvider.
---@class ai.router.ProviderMethods
---@field complete (fun(self: ai.router.ProviderMethods, body: table, upstream_model: string): ai.router.CanonicalMessage?, string?, table?)?
---@field completeStream (fun(self: ai.router.ProviderMethods, body: table, upstream_model: string, on_delta: fun(delta: table): boolean?): ai.router.CanonicalMessage?, string?, table?)?
---@field createResponse (fun(self: ai.router.ProviderMethods, body: table, upstream_model: string, session_id: string?, on_event: (fun(event: table): boolean?)?): table?, string?, table?)?
---@field fetchUsage (fun(self: ai.router.ProviderMethods): table?, string?, table?)?

---@class ai.router.ServerOptions
---@field scheduler web.CosocketScheduler
---@field users_repo ai.router.UsersRepo
---@field usage_repo ai.router.UsageRepo
---@field monitor ai.router.UsageMonitor
---@field provider_factory fun(subscription: ai.router.SubscriptionRow): ai.router.ProviderMethods?
---@field staleness number?
---@field logger (fun(line: string))?
---@field get_time (fun(): number)?
---@field client_timeout number?
---@field max_body_size integer?
---@field max_clients integer?
---@field max_concurrent_requests_per_user integer?
---@field max_requests_per_minute integer?
---@field cooldown_seconds number?
---@field admin_handler (fun(req: web.Request, res: web.Response): boolean?)?

---@param options ai.router.ServerOptions
function Server:new(options)
	assert(options.provider_factory, "provider_factory is required")
	self.users_repo = options.users_repo
	self.usage_repo = options.usage_repo
	self.monitor = options.monitor
	self.provider_factory = options.provider_factory
	self.logger = options.logger or print
	self.get_time = options.get_time or socket.gettime
	self.max_body_size = options.max_body_size or self.max_body_size
	self.max_concurrent_requests_per_user = options.max_concurrent_requests_per_user
		or self.max_concurrent_requests_per_user
	self.max_requests_per_minute = options.max_requests_per_minute or self.max_requests_per_minute
	self.cooldown_seconds = options.cooldown_seconds or self.cooldown_seconds
	self.admin_handler = options.admin_handler
	self.cooldowns = {}
	self.active_requests = {}
	self.request_windows = {}
	self.providers = {}
	self.catalog_errors = {}
	self.router = Router({state = Catalog.fromRows({}, {})})
	local max_clients = options.max_clients or self.max_clients
	assert(self.max_body_size >= 1, "max_body_size must be positive")
	assert(max_clients >= 1, "max_clients must be positive")
	assert(self.max_concurrent_requests_per_user >= 1, "max_concurrent_requests_per_user must be positive")
	assert(self.max_requests_per_minute >= 1, "max_requests_per_minute must be positive")
	self.http_server = HttpServer(options.scheduler, function(req, res, ip)
		self:handle(req, res, ip)
	end, {
		client_timeout = options.client_timeout or 30,
		max_clients = max_clients,
		max_header_size = 16384,
		max_header_count = 64,
	})
end

-- Rebuilds routing state, providers, and monitor wiring from repository
-- rows. Called at startup and after catalog mutations or an explicit retry.
---@param subscription_rows ai.router.SubscriptionRow[]
---@param model_rows ai.router.ModelRow[]
function Server:reload(subscription_rows, model_rows)
	local state, errors = Catalog.fromRows(subscription_rows, model_rows)
	self.catalog_errors = errors
	assert(#errors == 0, "invalid router catalog:\n" .. table.concat(errors, "\n"))
	local router = Router({state = state})
	---@type {[integer]: ai.router.ProviderMethods}
	local providers = {}
	---@type {[integer]: fun(): table?, string?, table?}
	local fetchers = {}
	for _, row in ipairs(subscription_rows) do
		local provider = self.provider_factory(row)
		if provider then
			providers[row.id] = provider
			if provider.fetchUsage then
				fetchers[row.id] = function()
					return provider:fetchUsage()
				end
			end
		end
	end
	self.monitor:setSubscriptions(state.subscriptions, fetchers)
	self.router = router
	self.providers = providers
end

---@param res web.Response
---@param status integer
---@param message string
---@param error_type string
---@param code string
local function sendError(res, status, message, error_type, code)
	local body = json.encode({
		error = {
			message = message,
			type = error_type,
			code = code,
		},
	})
	res.status = status
	res.headers:set("Content-Type", "application/json")
	if status == 401 then res.headers:set("WWW-Authenticate", "Bearer") end
	res:set_length(#body)
	res:send(body)
end

---@param res web.Response
---@param body table
---@return boolean
local function sendJson(res, body)
	local encoded = json.encode(body)
	res.status = 200
	res.headers:set("Content-Type", "application/json")
	res.headers:set("Cache-Control", "no-store")
	res:set_length(#encoded)
	return res:send(encoded) ~= nil
end

---@param res web.Response
---@param event table|string
---@return boolean
local function sendEvent(res, event)
	local data = type(event) == "string" and event or json.encode(event)
	local sent = res:send("data: " .. data .. "\n\n")
	return sent ~= nil
end

---@param res web.Response
---@return boolean
local function startEventStream(res)
	if res.headers_sent then return true end
	res.status = 200
	res.headers:set("Content-Type", "text/event-stream")
	res.headers:set("Cache-Control", "no-cache")
	res:set_chunked_encoding()
	return res:send_headers() ~= nil
end

---@param value any
---@return string
local function sanitizeLogValue(value)
	local sanitized = string.gsub(tostring(value), "[%c\127]", "?")
	return sanitized
end

---@param completion_id string
---@param created integer
---@param public_model string
---@param delta table
---@param finish_reason string?
---@param include_usage boolean
---@return table
local function chunkEvent(completion_id, created, public_model, delta, finish_reason, include_usage)
	return {
		id = completion_id,
		object = "chat.completion.chunk",
		created = created,
		model = public_model,
		choices = {{index = 0, delta = delta, finish_reason = finish_reason}},
		usage = include_usage and json.null or nil,
	}
end

---@param completion_id string
---@param created integer
---@param public_model string
---@param usage table
---@return table
local function usageChunkEvent(completion_id, created, public_model, usage)
	return {
		id = completion_id,
		object = "chat.completion.chunk",
		created = created,
		model = public_model,
		choices = json.array({}),
		usage = usage,
	}
end

---@param usage ai.router.CanonicalUsage?
---@return table?
local function ccUsage(usage)
	if not usage then return nil end
	---@type table
	local result = {
		prompt_tokens = usage.input_tokens,
		completion_tokens = usage.output_tokens,
		total_tokens = usage.input_tokens + usage.output_tokens,
	}
	if usage.cached_input_tokens > 0 then
		result.prompt_tokens_details = {cached_tokens = usage.cached_input_tokens}
	end
	return result
end

---@param message ai.router.CanonicalMessage
---@return string
local function finishReason(message)
	if message.finish_reason then return message.finish_reason end
	if message.tool_calls and message.tool_calls[1] then return "tool_calls" end
	return "stop"
end

-- Estimates token counts when the provider did not report usage.
---@param value any
---@return integer
local function estimate(value)
	if value == nil then return 0 end
	return math.ceil(#json.encode(value) / 4)
end

---@param req web.Request
---@return string? token
function Server:authenticate(req)
	local authorization = req.headers:get("Authorization")
	local token = authorization and authorization:match("^Bearer (.+)$")
	return token
end

---@param user_key string
---@param limit integer?
---@return boolean
function Server:consumeRateLimit(user_key, limit)
	local now = self.get_time()
	local window = self.request_windows[user_key]
	if not window or now - window.started_at >= 60 then
		self.request_windows[user_key] = {started_at = now, count = 1}
		return true
	elseif window.count >= (limit or self.max_requests_per_minute) then
		return false
	end
	window.count = window.count + 1
	return true
end

---@param user_key string
---@param limit integer?
---@return boolean
function Server:acquireRequest(user_key, limit)
	local active = self.active_requests[user_key] or 0
	if active >= (limit or self.max_concurrent_requests_per_user) then return false end
	self.active_requests[user_key] = active + 1
	return true
end

---@param user_key string
function Server:releaseRequest(user_key)
	local active = assert(self.active_requests[user_key]) - 1
	self.active_requests[user_key] = active > 0 and active or nil
end

-- One upstream attempt. Returns "done" when the response is fully written,
-- or "failover" when the walk should continue with the next candidate.
-- `attempt` mutates only local state; cooldowns and refreshes are returned
-- through the result table.
---@class ai.router.AttemptResult
---@field status "done"|"failover"
---@field message ai.router.CanonicalMessage?
---@field response table? Native Responses result; never converted to a canonical assistant message.
---@field provider_error table?
---@field cooldown boolean?
---@field refresh_usage boolean?
---@field downstream_closed boolean?
---@field subscription string?
---@field upstream_model string?
---@field status_code integer? Logical request outcome, including failures after HTTP 200 commit.

---@param self ai.router.Server
---@param res web.Response
---@param request {[string]: any}
---@param public_model string
---@param candidate ai.router.Candidate
---@param completion_id string
---@param created integer
---@param include_usage boolean
---@return ai.router.AttemptResult
local function attempt(self, res, request, public_model, candidate, completion_id, created, include_usage)
	local provider = self.providers[candidate.subscription.id]
	if not provider then
		return {status = "failover"}
	end
	local stream = request.stream == true
	local body = request
	if body.model ~= candidate.model then
		---@type {[string]: any}
		local copy = {}
		---@cast body {[string]: any}
		for key, value in pairs(body) do
			copy[key] = value
		end
		copy.model = candidate.model
		body = copy
	end
	local upstream_model = candidate.upstream_model

	if not stream then
		local ok, message, err, provider_error = pcall(provider.complete, provider, body, upstream_model)
		if not ok then message, err = nil, "upstream request failed" end
		if not message then
			local status = provider_error and provider_error.status
			if status == 400 then
				sendError(res, 400, provider_error.message, provider_error.type, provider_error.code)
				return {status = "done", status_code = 400, provider_error = provider_error,
					subscription = candidate.subscription.name, upstream_model = candidate.upstream_model}
			end
			return {
				status = "failover",
				provider_error = provider_error or {message = err, type = "upstream_error", code = "upstream_error"},
				cooldown = status == 401 or status == 403,
				refresh_usage = status == 429 or provider_error and provider_error.type == "rate_limit_error",
				subscription = candidate.subscription.name,
				upstream_model = candidate.upstream_model,
			}
		end
		local completion = {
			id = completion_id,
			object = "chat.completion",
			created = created,
			model = public_model,
			choices = {{
				index = 0,
				message = message,
				finish_reason = finishReason(message),
			}},
		}
		local usage = ccUsage(message.usage)
		if usage then completion.usage = usage end
		local sent = sendJson(res, completion)
		return {status = "done", message = message, downstream_closed = not sent, status_code = sent and 200 or 499,
			subscription = candidate.subscription.name, upstream_model = candidate.upstream_model}
	end

	-- Streaming: commit downstream only when the first output delta arrives.
	local committed = false
	local downstream_closed = false
	local function commit()
		if committed then return true end
		if not startEventStream(res)
			or not sendEvent(res, chunkEvent(completion_id, created, public_model,
				{role = "assistant"}, nil, include_usage))
		then
			return false
		end
		committed = true
		return true
	end
	local ok, message, err, provider_error = pcall(provider.completeStream, provider, body, upstream_model, function(delta)
		if downstream_closed then return false end
		-- Role announcements and empty deltas are not assistant output.
		if not committed then
			local has_output = false
			for key, value in pairs(delta) do
				if key ~= "role" and value ~= json.null and value ~= ""
					and (type(value) ~= "table" or next(value)) then has_output = true break end
			end
			if not has_output then return true end
		end
		if not commit() then
			downstream_closed = true
			return false
		end
		local sent = sendEvent(res, chunkEvent(completion_id, created, public_model, delta, nil, include_usage))
		if not sent then
			downstream_closed = true
			return false
		end
		return true
	end)
	if not ok then message, err = nil, "upstream request failed" end
	if not message then
		if downstream_closed then
			return {status = "done", status_code = 499, downstream_closed = true}
		end
		if committed or res.headers_sent then
			local error_body = provider_error or {
				message = "upstream request failed",
				type = "upstream_error",
				code = "upstream_error",
			}
			---@cast error_body {[string]: any}
			local sent = sendEvent(res, {error = {
				message = error_body.message,
				type = error_body.type,
				code = error_body.code,
				request_id = error_body.request_id,
			}})
			if sent then sent = sendEvent(res, "[DONE]") end
			if sent then sent = res:send("") ~= nil end
			return {status = "done", status_code = sent and 502 or 499, downstream_closed = not sent, provider_error = error_body,
				cooldown = error_body.status == 401 or error_body.status == 403,
				refresh_usage = error_body.status == 429 or error_body.type == "rate_limit_error",
				subscription = candidate.subscription.name, upstream_model = candidate.upstream_model}
		end
		local status = provider_error and provider_error.status
		if status == 400 then
			sendError(res, 400, provider_error.message, provider_error.type, provider_error.code)
			return {status = "done", status_code = 400, provider_error = provider_error}
		end
		return {
			status = "failover",
			provider_error = provider_error or {message = err, type = "upstream_error", code = "upstream_error"},
			cooldown = status == 401 or status == 403,
			refresh_usage = status == 429 or provider_error and provider_error.type == "rate_limit_error",
		}
	end
	if downstream_closed or not commit() then
		return {status = "done", status_code = 499, message = message, downstream_closed = true}
	end
	local sent = sendEvent(res, chunkEvent(completion_id, created, public_model, json.object(), finishReason(message), include_usage))
	if sent and include_usage then
		local usage = ccUsage(message.usage)
		if usage then
			sent = sendEvent(res, usageChunkEvent(completion_id, created, public_model, usage))
		end
	end
	if sent then sent = sendEvent(res, "[DONE]") end
	if sent then sent = res:send("") ~= nil end
	return {status = "done", message = message, downstream_closed = not sent, status_code = sent and 200 or 499}
end

---@param res web.Response
---@param event {[string]: any}
---@return boolean
local function sendResponseEvent(res, event)
	local event_type = type(event.type) == "string" and event.type:match("^[%w._-]+$") or nil
	local prefix = event_type and "event: " .. event_type .. "\n" or ""
	return res:send(prefix .. "data: " .. json.encode(event) .. "\n\n") ~= nil
end

---@param response {[string]: any}
---@param model string
---@return table
local function publicResponse(response, model)
	---@type {[string]: any}
	local copy = {}
	for key, value in pairs(response) do copy[key] = value end
	copy.model = model
	return copy
end

-- Native SSE commits on the first typed event, including response.created.
-- After that point neither the response identity nor the serving subscription can change.
---@param self ai.router.Server
---@param res web.Response
---@param request {[string]: any}
---@param public_model string
---@param candidate ai.router.Candidate
---@param session_id string?
---@return ai.router.AttemptResult
local function attemptResponse(self, res, request, public_model, candidate, session_id)
	local provider = self.providers[candidate.subscription.id]
	if not provider then return {status = "failover"} end
	local committed, downstream_closed = false, false
	local sequence_number = -1
	---@type (fun(event: table): boolean?)?
	local callback
	if request.stream == true then
		---@param event {[string]: any}
		---@return boolean
		function callback(event)
			if downstream_closed then return false end
			sequence_number = type(event.sequence_number) == "number" and event.sequence_number or sequence_number + 1
			committed = true
			if not startEventStream(res) then downstream_closed = true return false end
			if type(event.response) == "table" then
				---@type {[string]: any}
				local copy = {}
				for key, value in pairs(event) do copy[key] = value end
				copy.response = publicResponse(event.response, public_model)
				event = copy
			end
			if not sendResponseEvent(res, event) then downstream_closed = true return false end
			return true
		end
	end
	local ok, response, _, provider_error = pcall(provider.createResponse, provider,
		request, candidate.upstream_model, session_id, callback)
	if not ok then response = nil end
	if downstream_closed then return {status = "done", status_code = 499, downstream_closed = true} end
	if not response then
		local error_body = provider_error or {message = "upstream request failed", type = "upstream_error", code = "upstream_error"}
		local status = error_body.status
		---@type ai.router.AttemptResult
		local result = {
			status = "failover", provider_error = error_body,
			cooldown = status == 401 or status == 403,
			refresh_usage = status == 429 or error_body.type == "rate_limit_error",
		}
		if committed or res.headers_sent then
			local sent = sendResponseEvent(res, {type = "error", code = error_body.code,
				message = error_body.message, param = json.null, sequence_number = sequence_number + 1})
			if sent then sent = res:send("") ~= nil end
			result.status, result.status_code = "done", sent and 502 or 499
			result.downstream_closed = not sent
		elseif status == 400 then
			sendError(res, 400, error_body.message, error_body.type, error_body.code)
			result.status, result.status_code = "done", 400
		end
		return result
	end
	local sent
	if request.stream == true then
		sent = startEventStream(res) and res:send("") ~= nil
	else
		sent = sendJson(res, publicResponse(response, public_model))
	end
	local response_error = response.error
	return {status = "done", response = response, downstream_closed = not sent,
		refresh_usage = type(response_error) == "table"
			and (response_error.code == "rate_limit_exceeded" or response_error.type == "rate_limit_error"),
		status_code = not sent and 499 or response.status == "failed" and 502 or 200}
end

-- Resolves and walks candidates within the requested native protocol only.
---@param res web.Response
---@param request {[string]: any}
---@param user ai.router.UserRow
---@param protocol "responses"|"chat_completions"?
---@param session_id string?
---@return integer status
---@return ai.router.AttemptResult? result
function Server:complete(res, request, user, protocol, session_id)
	local public_model = request.model
	---@type {[string]: boolean}
	local grants = {}
	for _, model in ipairs(self.users_repo:getGrants(user.id)) do
		grants[model] = true
	end
	if type(public_model) ~= "string" or not grants[public_model]
		or not self.router.state.public_models[public_model] then
		sendError(res, 404, "model is not available", "invalid_request_error", "model_not_found")
		return 404
	end
	local candidates = self.router:candidates(public_model)
	if not candidates or #candidates == 0 then
		sendError(res, 503, "no upstream is available for this model", "upstream_error", "upstream_unavailable")
		return 503
	end
	local native = protocol == "responses"
	---@type ai.router.Candidate[]
	local compatible = {}
	for _, candidate in ipairs(candidates) do
		if (candidate.subscription.kind == "openai") == native then
			table.insert(compatible, candidate)
		end
	end
	if #compatible == 0 then
		sendError(res, 400, "model is not available on this endpoint; use its native protocol",
			"invalid_request_error", "unsupported_protocol")
		return 400
	end
	candidates = compatible
	if native then
		local message, code = ResponsesProtocol.validateRequest(request)
		if message then
			sendError(res, 400, message, "invalid_request_error", assert(code))
			return 400
		end
		session_id = session_id or ResponsesProtocol.cacheSessionId(request.prompt_cache_key)
	end

	local completion_id = "chatcmpl-" .. random.hex(16)
	local created = os.time()
	local stream_options = request.stream_options
	local include_usage = type(stream_options) == "table" and stream_options.include_usage == true or false
	local start_index = 1
	while true do
		local index, candidate = self.router:select(candidates, start_index,
			self.monitor.windows, self.cooldowns, self.get_time())
		if not index then
			sendError(res, 503, "no upstream is available for this model", "upstream_error", "upstream_unavailable")
			return 503
		end
		local result
		if native then
			result = attemptResponse(self, res, request, public_model, candidate, session_id)
		else
			result = attempt(self, res, request, public_model, candidate, completion_id, created, include_usage)
		end
		result.subscription, result.upstream_model = candidate.subscription.name, candidate.upstream_model
		if result.cooldown then
			self.cooldowns[candidate.subscription.id] = self.get_time() + self.cooldown_seconds
		end
		if result.refresh_usage then
			self.monitor:refresh(candidate.subscription.id)
		end
		if result.status == "done" then return result.status_code or 200, result end
		start_index = index + 1
	end
end

-- Records one completed request. Called for every authenticated inference
-- attempt, including local rejections and upstream errors.
---@param now number
---@param user ai.router.UserRow
---@param status integer
---@param request {[string]: any}?
---@param result ai.router.AttemptResult?
function Server:record(now, user, status, request, result)
	if not request then return end
	local public_model = type(request.model) == "string" and request.model or ""
	local message = result and result.message
	local response = result and result.response
	local usage = response and Provider.canonicalUsage(response.usage) or message and message.usage
	local input_tokens = usage and usage.input_tokens or 0
	local output_tokens = usage and usage.output_tokens or 0
	local cached = usage and usage.cached_input_tokens or 0
	if not usage then
		input_tokens = estimate({messages = request.messages, tools = request.tools,
			input = request.input, instructions = request.instructions})
		output_tokens = response and estimate(response.output)
			or message and estimate({content = message.content, tool_calls = message.tool_calls}) or 0
	end
	local subscription = ""
	local upstream_model = ""
	if result then
		if result.subscription then subscription = result.subscription end
		if result.upstream_model then upstream_model = result.upstream_model end
	end
	pcall(function()
		self.usage_repo:record(now, user.name, status, public_model, upstream_model, subscription, {
			input_tokens = input_tokens,
			output_tokens = output_tokens,
			cached_input_tokens = cached,
			estimated = usage == nil,
		})
	end)
end

---@param req web.Request
---@param res web.Response
---@param ip string
function Server:handle(req, res, ip)
	if self.admin_handler and self.admin_handler(req, res) then
		return
	end
	local started_at = self.get_time()
	local token = self:authenticate(req)
	local user = token and self.users_repo:findByKeyHash(digest.hash("sha256", token, true)) or nil
	---@type integer
	local status
	---@type ai.router.AttemptResult?
	local attempt_result
	local should_record = false
	---@type table?
	local request
	local path = req.uri:match("^[^?]+") or req.uri
	if not user or user.disabled then
		sendError(res, 401, "invalid access token", "authentication_error", "invalid_api_key")
		status = 401
	elseif req.method == "GET" and path == "/v1/models" then
		local grants = {}
		for _, model in ipairs(self.users_repo:getGrants(user.id)) do
			if self.router.state.public_models[model] then
				table.insert(grants, {id = model, object = "model", owned_by = "router"})
			end
		end
		sendJson(res, {object = "list", data = json.array(grants)})
		status = 200
	elseif req.method ~= "POST" or (path ~= "/v1/chat/completions" and path ~= "/v1/responses") then
		sendError(res, 404, "route not found", "invalid_request_error", "not_found")
		status = 404
	elseif not self:consumeRateLimit(tostring(user.id), user.max_rpm) then
		res.headers:set("Retry-After", 60)
		sendError(res, 429, "rate limit exceeded", "rate_limit_error", "rate_limit_exceeded")
		status = 429
	elseif not self:acquireRequest(tostring(user.id), user.max_concurrency) then
		res.headers:set("Retry-After", 1)
		sendError(res, 429, "too many concurrent requests", "rate_limit_error", "concurrency_limit_exceeded")
		status = 429
	else
		should_record = true
		local ok = pcall(function()
			local transfer_encodings = req.headers:getTable("Transfer-Encoding")
			local content_lengths = req.headers:getTable("Content-Length")
			if #transfer_encodings > 0 then
				sendError(res, 400, "Transfer-Encoding is not supported", "invalid_request_error", "unsupported_transfer_encoding")
				status = 400
			elseif #content_lengths == 0 then
				sendError(res, 411, "Content-Length is required", "invalid_request_error", "length_required")
				status = 411
			elseif #content_lengths ~= 1 then
				sendError(res, 400, "multiple Content-Length headers are not allowed", "invalid_request_error", "invalid_content_length")
				status = 400
			else
				local content_length = tonumber(content_lengths[1])
				if not content_length then
					sendError(res, 400, "Content-Length is invalid", "invalid_request_error", "invalid_content_length")
					status = 400
				elseif content_length > self.max_body_size then
					sendError(res, 413, "request body is too large", "invalid_request_error", "request_too_large")
					status = 413
				else
					local body, receive_err = req:receive("*a")
					if body then
						local decoded, decode_err = json.decode_safe(body)
						if type(decoded) ~= "table" then
							sendError(res, 400, "invalid JSON body: " .. tostring(decode_err), "invalid_request_error", "invalid_json")
							status = 400
						else
							request = decoded
							local native = path == "/v1/responses"
							local session_id, session_err
							if native then session_id, session_err = ResponsesProtocol.getSessionAffinity(req) end
							if session_err then
								sendError(res, 400, session_err, "invalid_request_error", "invalid_session_affinity")
								status = 400
							else
								status, attempt_result = self:complete(res, request, user,
									native and "responses" or "chat_completions", session_id)
							end
						end
					else
						sendError(res, 400, "invalid JSON body: " .. tostring(receive_err), "invalid_request_error", "invalid_json")
						status = 400
					end
				end
			end
		end)
		self:releaseRequest(tostring(user.id))
		if not ok then
			status = 500
			-- Never expose exception text or replace a committed SSE response with JSON.
			pcall(function()
				if res.headers_sent then
					-- Native Responses closes here: this handler has no attempt sequence state.
					if path ~= "/v1/responses" then
						sendEvent(res, {error = {message = "request failed", type = "internal_error", code = "internal_error"}})
						sendEvent(res, "[DONE]")
					end
					res:send("")
				else
					sendError(res, 500, "request failed", "internal_error", "internal_error")
				end
			end)
		end
	end
	if should_record and user then
		self:record(os.time(), user, status, request, attempt_result)
	end
	self.logger(("user=%s ip=%s method=%s path=%s status=%d duration=%.3fs")
		:format(
			sanitizeLogValue(user and user.name or "-"),
			sanitizeLogValue(ip),
			sanitizeLogValue(req.method),
			sanitizeLogValue(path),
			status,
			self.get_time() - started_at
		))
end

---@param host string
---@param port integer
---@return true?
---@return string?
function Server:start(host, port)
	return self.http_server:start(host, port)
end

function Server:stop()
	self.http_server:stop()
end

---@return string?
---@return integer?
function Server:getAddress()
	return self.http_server:getAddress()
end

return Server
