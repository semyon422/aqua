local class = require("class")
local coext = require("coext")

---@class ai.router.WindowSnapshot
---@field used_percent number?
---@field used_tokens integer?
---@field quota_tokens integer?
---@field reset_at integer? unix seconds
---@field source "upstream"|"local"
---@field updated_at number unix seconds of the poll

---@alias ai.router.UsagePollErrorCode "auth"|"transport"|"upstream_http"|"cloudflare_challenge"|"invalid_response"|"internal_error"

---@class ai.router.UsageFetchError
---@field code ai.router.UsagePollErrorCode
---@field status integer? upstream HTTP status, never a fabricated transport status

---@class ai.router.UsagePollError
---@field code ai.router.UsagePollErrorCode
---@field message string
---@field http_status integer?

---@class ai.router.UsagePollStatus
---@field attempted_at number
---@field succeeded_at number?
---@field error ai.router.UsagePollError?

-- Maintains informational channel quotas in memory. Polls upstream monitors
-- and estimates local windows from usage aggregates. Failed polls retain the
-- previous snapshot and its timestamp; none of this state affects routing.
---@class ai.router.UsageMonitor
---@operator call: ai.router.UsageMonitor
---@field poll_status {[integer]: ai.router.UsagePollStatus}
---@field windows {[integer]: {[string]: ai.router.WindowSnapshot}}
---@field channels ai.router.ChannelState[]
---@field channels_by_id {[integer]: ai.router.ChannelState}
---@field fetchers {[integer]: fun(): table?, string?, ai.router.UsageFetchError?}
---@field last_poll {[integer]: number}
---@field usage_repo ai.router.UsageRepo
---@field logger fun(line: string)
---@field get_time fun(): number
---@field default_interval integer
local UsageMonitor = class()

---@type {[ai.router.UsagePollErrorCode]: string}
local poll_errors = {
	auth = "Upstream authentication failed; check channel credentials.",
	transport = "Could not reach the upstream usage endpoint.",
	upstream_http = "Upstream usage endpoint returned an HTTP error.",
	cloudflare_challenge = "Cloudflare blocked the usage request with a browser challenge.",
	invalid_response = "Upstream usage response is missing expected quota data.",
	internal_error = "Usage polling failed internally.",
}

UsageMonitor.default_interval = 60
UsageMonitor.window_seconds = {
	five_hour = 5 * 3600,
	weekly = 7 * 24 * 3600,
}

---@class ai.router.UsageMonitorOptions
---@field usage_repo ai.router.UsageRepo
---@field get_time (fun(): number)?
---@field logger (fun(line: string))?
---@field default_interval integer?

---@param options ai.router.UsageMonitorOptions
function UsageMonitor:new(options)
	self.usage_repo = options.usage_repo
	self.get_time = options.get_time or os.time
	self.logger = options.logger or function() end
	self.default_interval = options.default_interval or UsageMonitor.default_interval
	self.windows = {}
	self.channels = {}
	self.channels_by_id = {}
	self.fetchers = {}
	self.last_poll = {}
	self.poll_status = {}
end

-- Starts the process-lifetime background loop, including the first poll.
---@param scheduler web.CosocketScheduler
---@return thread
function UsageMonitor:startPolling(scheduler)
	local co = coext.detach(coroutine.create(function()
		while true do
			self:update(self.get_time())
			scheduler:sleep(5)
		end
	end))
	scheduler:resume(co)
	return co
end

-- Installs the current catalog states and their usage fetchers. Window state
-- for channels that no longer exist is dropped.
---@param channels ai.router.ChannelState[]
---@param fetchers {[integer]: fun(): table?, string?, ai.router.UsageFetchError?}
function UsageMonitor:setChannels(channels, fetchers)
	self.channels = channels
	---@type {[integer]: ai.router.ChannelState}
	local by_id = {}
	for _, channel in ipairs(channels) do
		by_id[channel.id] = channel
	end
	self.channels_by_id = by_id
	self.fetchers = fetchers
	---@type {[integer]: boolean}
	local live = {}
	for id in pairs(by_id) do
		live[id] = true
	end
	for id in pairs(self.windows) do
		if not live[id] then
			self.windows[id] = nil
		end
	end
	for id in pairs(self.last_poll) do
		if not live[id] then
			self.last_poll[id] = nil
			self.poll_status[id] = nil
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

---@param channel ai.router.ChannelState
---@param window "five_hour"|"weekly"
---@return integer? quota
local function windowQuota(channel, window)
	if window == "five_hour" then
		return channel.five_hour_quota_tokens
	end
	return channel.weekly_quota_tokens
end

---@param channel ai.router.ChannelState
---@param window "five_hour"|"weekly"
---@param fields {used_percent: number?, used_tokens: integer?, quota_tokens: integer?, reset_at: integer?}
---@param source "upstream"|"local"
---@param now number
function UsageMonitor:saveWindow(channel, window, fields, source, now)
	local snapshot = {
		used_percent = fields.used_percent,
		used_tokens = fields.used_tokens,
		quota_tokens = fields.quota_tokens,
		reset_at = fields.reset_at,
		source = source,
		updated_at = now,
	}
	if not self.windows[channel.id] then
		self.windows[channel.id] = {}
	end
	self.windows[channel.id][window] = snapshot
end

-- Computes a local-counting window from usage aggregates against the
-- configured token quota. Quota-less windows keep no state.
---@param channel ai.router.ChannelState
---@param window "five_hour"|"weekly"
---@param now number
function UsageMonitor:countLocally(channel, window, now)
	local quota = windowQuota(channel, window)
	if quota == nil then return end
	local tokens = self.usage_repo:channelTokens(channel.name, now, UsageMonitor.window_seconds[window])
	self:saveWindow(channel, window, {
		used_percent = tokens / quota * 100,
		used_tokens = tokens,
		quota_tokens = quota,
	}, "local", now)
end

---@param channel ai.router.ChannelState
---@param now number
---@param code ai.router.UsagePollErrorCode
---@param http_status integer?
function UsageMonitor:pollFailed(channel, now, code, http_status)
	local previous = self.poll_status[channel.id]
	local poll_error = {code = code, message = assert(poll_errors[code]), http_status = http_status}
	self.poll_status[channel.id] = {attempted_at = now,
		succeeded_at = previous and previous.succeeded_at, error = poll_error}
	self.logger(("channel=%s usage poll failed: %s%s"):format(channel.name, code,
		http_status and (" (HTTP " .. http_status .. ")") or ""))
end

-- Polls one channel now: upstream windows through its fetcher, local
-- windows from aggregates. Failed fetches keep previous state.
---@param channel ai.router.ChannelState
---@param now number
function UsageMonitor:pollChannel(channel, now)
	for _, window in ipairs({"five_hour", "weekly"}) do
		if channel.usage_source[window] == "local" then
			self:countLocally(channel, window, now)
		end
	end
	local fetcher = self.fetchers[channel.id]
	if not fetcher or (channel.usage_source.five_hour ~= "upstream" and channel.usage_source.weekly ~= "upstream") then
		self.poll_status[channel.id] = nil
		return
	end
	local ok, usage, _, provider_error = pcall(fetcher)
	if not usage or not ok then
		local code = ok and "transport" or "internal_error"
		---@type integer?
		local http_status
		if ok and type(provider_error) == "table" then
			local reported_code = provider_error.code
			if type(reported_code) == "string" and poll_errors[reported_code] then
				code = reported_code
			end
			local status = provider_error.status
			if type(status) == "number" and status % 1 == 0 and status >= 100 and status <= 599 then
				http_status = status
			end
		end
		---@cast code ai.router.UsagePollErrorCode
		self:pollFailed(channel, now, code, http_status)
		return
	end
	---@cast usage {[string]: any}
	---@type {[string]: {used_percent: number?, used_tokens: integer?, quota_tokens: integer?, reset_at: integer?}}
	local windows
	if channel.kind == "openai" then
		windows = UsageMonitor.parseOpenAIUsage(usage)
	elseif channel.kind == "zai" then
		windows = UsageMonitor.parseZaiUsage(usage)
	else
		return
	end
	local complete = true
	for _, window in ipairs({"five_hour", "weekly"}) do
		if channel.usage_source[window] == "upstream" then
			local fields = windows[window]
			if fields and fields.used_percent ~= nil then
				self:saveWindow(channel, window, fields, "upstream", now)
			else
				complete = false
			end
		end
	end
	if not complete then
		self:pollFailed(channel, now, "invalid_response")
		return
	end
	self.poll_status[channel.id] = {attempted_at = now, succeeded_at = now}
end

-- Polls every channel whose interval has elapsed.
---@param now number?
function UsageMonitor:update(now)
	now = now or self.get_time()
	for _, channel in ipairs(self.channels) do
		if not channel.enabled then
			self.windows[channel.id] = nil
			self.poll_status[channel.id] = nil
		else
			local interval = channel.poll_interval or self.default_interval
			local last = self.last_poll[channel.id]
			if last == nil or now - last >= interval then
				self.last_poll[channel.id] = now
				self:pollChannel(channel, now)
			end
		end
	end
end

-- Forces an immediate poll of one channel; used after a quota error.
---@param channel_id integer
---@param now number?
function UsageMonitor:refresh(channel_id, now)
	now = now or self.get_time()
	local channel = self.channels_by_id[channel_id]
	if not channel or not channel.enabled then return end
	self.last_poll[channel_id] = now
	self:pollChannel(channel, now)
end

return UsageMonitor
