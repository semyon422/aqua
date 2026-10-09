local class = require("class")

---@class ai.router.WindowSnapshot
---@field used_percent number?
---@field used_tokens integer?
---@field quota_tokens integer?
---@field reset_at integer? unix seconds
---@field source "upstream"|"local"
---@field updated_at number unix seconds of the poll

-- Maintains per-subscription usage-window state for routing decisions.
-- Polls upstream monitor endpoints through injected provider fetchers,
-- computes local-counting windows from usage aggregates, keeps the in-memory
-- state the Router selects against, and persists snapshots through
-- WindowsRepo so fills survive restarts. Failed polls keep the previous
-- snapshot; stale data never depletes a subscription.
---@class ai.router.UsageMonitor
---@operator call: ai.router.UsageMonitor
---@field windows {[integer]: {[string]: ai.router.WindowSnapshot}}
---@field subscriptions ai.router.SubscriptionState[]
---@field subscriptions_by_id {[integer]: ai.router.SubscriptionState}
---@field fetchers {[integer]: fun(): table?, string?, table?}
---@field last_poll {[integer]: number}
---@field usage_repo ai.router.UsageRepo
---@field windows_repo ai.router.WindowsRepo
---@field logger fun(line: string)
---@field get_time fun(): number
---@field default_interval integer
local UsageMonitor = class()

UsageMonitor.default_interval = 60
UsageMonitor.window_seconds = {
	five_hour = 5 * 3600,
	weekly = 7 * 24 * 3600,
}

---@class ai.router.UsageMonitorOptions
---@field usage_repo ai.router.UsageRepo
---@field windows_repo ai.router.WindowsRepo
---@field get_time (fun(): number)?
---@field logger (fun(line: string))?
---@field default_interval integer?

---@param options ai.router.UsageMonitorOptions
function UsageMonitor:new(options)
	self.usage_repo = options.usage_repo
	self.windows_repo = options.windows_repo
	self.get_time = options.get_time or os.time
	self.logger = options.logger or function() end
	self.default_interval = options.default_interval or UsageMonitor.default_interval
	self.windows = {}
	self.subscriptions = {}
	self.subscriptions_by_id = {}
	self.fetchers = {}
	self.last_poll = {}
end

-- Installs the current catalog states and their usage fetchers. Window state
-- for subscriptions that no longer exist is dropped.
---@param subscriptions ai.router.SubscriptionState[]
---@param fetchers {[integer]: fun(): table?, string?, table?}
function UsageMonitor:setSubscriptions(subscriptions, fetchers)
	self.subscriptions = subscriptions
	---@type {[integer]: ai.router.SubscriptionState}
	local by_id = {}
	for _, subscription in ipairs(subscriptions) do
		by_id[subscription.id] = subscription
	end
	self.subscriptions_by_id = by_id
	self.fetchers = fetchers
	---@type {[integer]: boolean}
	local live = {}
	for id in pairs(by_id) do
		live[id] = true
	end
	for id in pairs(self.windows) do
		if not live[id] then
			self.windows[id] = nil
			self.last_poll[id] = nil
		end
	end
end

-- Extracts the five-hour and weekly windows from an upstream Codex usage
-- object: `rate_limit.primary_window` is the 5-hour window and
-- `secondary_window` the weekly one, each with `used_percent` and `reset_at`
-- (unix seconds).
---@param usage {[string]: any}
---@return {[string]: {used_percent: number?, used_tokens: integer?, quota_tokens: integer?, reset_at: integer?}} windows
function UsageMonitor.parseOpenAIUsage(usage)
	local rate_limit = usage.rate_limit
	---@type {[string]: {used_percent: number?, used_tokens: integer?, quota_tokens: integer?, reset_at: integer?}}
	local windows = {}
	if type(rate_limit) == "table" then
		---@cast rate_limit {[string]: any}
		for window_name, key in pairs({five_hour = "primary_window", weekly = "secondary_window"}) do
			local window = rate_limit[key]
			if type(window) == "table" then
				---@cast window {[string]: any}
				windows[window_name] = {
					used_percent = type(window.used_percent) == "number" and window.used_percent or nil,
					reset_at = type(window.reset_at) == "number" and window.reset_at or nil,
				}
			end
		end
	end
	return windows
end

-- Extracts the windows from a z.ai monitor `data` object: `unit 3/number 5`
-- is the five-hour window and `unit 6/number 1` the rolling weekly one, with
-- `percentage`, `usage` (quota), `currentValue` (consumption), and
-- `nextResetTime` (epoch milliseconds).
---@param data {[string]: any}
---@return {[string]: {used_percent: number?, used_tokens: integer?, quota_tokens: integer?, reset_at: integer?}} windows
function UsageMonitor.parseZaiUsage(data)
	local limits = data.limits
	---@type {[string]: {used_percent: number?, used_tokens: integer?, quota_tokens: integer?, reset_at: integer?}}
	local windows = {}
	if type(limits) ~= "table" then return windows end
	---@cast limits any[]
	for _, limit in ipairs(limits) do
		if type(limit) == "table" then
			---@cast limit {[string]: any}
			---@type ("five_hour"|"weekly")?
			local window_name
			if limit.unit == 3 and limit.number == 5 then
				window_name = "five_hour"
			elseif limit.unit == 6 and limit.number == 1 then
				window_name = "weekly"
			end
			if window_name then
				local reset_at = type(limit.nextResetTime) == "number"
					and math.floor(limit.nextResetTime / 1000) or nil
				windows[window_name] = {
					used_percent = type(limit.percentage) == "number" and limit.percentage or nil,
					used_tokens = type(limit.currentValue) == "number" and limit.currentValue or nil,
					quota_tokens = type(limit.usage) == "number" and limit.usage or nil,
					reset_at = reset_at,
				}
			end
		end
	end
	return windows
end

---@param subscription ai.router.SubscriptionState
---@param window "five_hour"|"weekly"
---@return integer? quota
local function windowQuota(subscription, window)
	if window == "five_hour" then
		return subscription.five_hour_quota_tokens
	end
	return subscription.weekly_quota_tokens
end

---@param subscription ai.router.SubscriptionState
---@param window "five_hour"|"weekly"
---@param fields {used_percent: number?, used_tokens: integer?, quota_tokens: integer?, reset_at: integer?}
---@param source "upstream"|"local"
---@param now number
function UsageMonitor:saveWindow(subscription, window, fields, source, now)
	local snapshot = {
		used_percent = fields.used_percent,
		used_tokens = fields.used_tokens,
		quota_tokens = fields.quota_tokens,
		reset_at = fields.reset_at,
		source = source,
		updated_at = now,
	}
	if not self.windows[subscription.id] then
		self.windows[subscription.id] = {}
	end
	self.windows[subscription.id][window] = snapshot
	self.windows_repo:save(subscription.id, window, {
		used_percent = fields.used_percent,
		used_tokens = fields.used_tokens,
		quota_tokens = fields.quota_tokens,
		reset_at = fields.reset_at,
		source = source,
	}, now)
end

-- Computes a local-counting window from usage aggregates against the
-- configured token quota. Quota-less windows keep no state.
---@param subscription ai.router.SubscriptionState
---@param window "five_hour"|"weekly"
---@param now number
function UsageMonitor:countLocally(subscription, window, now)
	local quota = windowQuota(subscription, window)
	if quota == nil then return end
	local tokens = self.usage_repo:subscriptionTokens(subscription.name, now, UsageMonitor.window_seconds[window])
	self:saveWindow(subscription, window, {
		used_percent = tokens / quota * 100,
		used_tokens = tokens,
		quota_tokens = quota,
	}, "local", now)
end

-- Polls one subscription now: upstream windows through its fetcher, local
-- windows from aggregates. Failed fetches keep previous state.
---@param subscription ai.router.SubscriptionState
---@param now number
function UsageMonitor:pollSubscription(subscription, now)
	for _, window in ipairs({"five_hour", "weekly"}) do
		if subscription.usage_source[window] == "local" then
			self:countLocally(subscription, window, now)
		end
	end
	local fetcher = self.fetchers[subscription.id]
	if not fetcher then return end
	local ok, usage, request_err = pcall(fetcher)
	if not ok then
		usage, request_err = nil, usage
	end
	if not usage then
		self.logger(("subscription=%s usage poll failed: %s")
			:format(subscription.name, tostring(request_err)))
		return
	end
	---@cast usage {[string]: any}
	---@type {[string]: {used_percent: number?, used_tokens: integer?, quota_tokens: integer?, reset_at: integer?}}
	local windows
	if subscription.kind == "openai" then
		windows = UsageMonitor.parseOpenAIUsage(usage)
	elseif subscription.kind == "zai" then
		windows = UsageMonitor.parseZaiUsage(usage)
	else
		return
	end
	for _, window in ipairs({"five_hour", "weekly"}) do
		if subscription.usage_source[window] == "upstream" then
			local fields = windows[window]
			if fields and fields.used_percent ~= nil then
				self:saveWindow(subscription, window, fields, "upstream", now)
			end
		end
	end
end

-- Polls every subscription whose interval has elapsed.
---@param now number?
function UsageMonitor:update(now)
	now = now or self.get_time()
	for _, subscription in ipairs(self.subscriptions) do
		if not subscription.enabled then
			self.windows[subscription.id] = nil
		else
			local interval = subscription.poll_interval or self.default_interval
			local last = self.last_poll[subscription.id]
			if last == nil or now - last >= interval then
				self.last_poll[subscription.id] = now
				self:pollSubscription(subscription, now)
			end
		end
	end
end

-- Forces an immediate poll of one subscription; used after a quota error.
---@param subscription_id integer
---@param now number?
function UsageMonitor:refresh(subscription_id, now)
	now = now or self.get_time()
	local subscription = self.subscriptions_by_id[subscription_id]
	if not subscription or not subscription.enabled then return end
	self.last_poll[subscription_id] = now
	self:pollSubscription(subscription, now)
end

return UsageMonitor
