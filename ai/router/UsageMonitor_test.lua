local UsageMonitor = require("ai.router.UsageMonitor")
local UsageRepo = require("ai.router.UsageRepo")
local WindowsRepo = require("ai.router.WindowsRepo")
local RouterDatabase = require("ai.router.storage.RouterDatabase")
local LjsqliteDatabase = require("rdb.db.LjsqliteDatabase")

local test = {}

---@param opts {id: integer?, name: string?, kind: string?, usage_source: table?, five_hour_quota_tokens: integer?, weekly_quota_tokens: integer?, poll_interval: integer?, enabled: boolean?}?
---@return ai.router.SubscriptionState
local function subState(opts)
	opts = opts or {}
	return {
		id = opts.id or 1,
		name = opts.name or "zai-1",
		kind = opts.kind or "zai",
		priority = 1,
		enabled = opts.enabled ~= false,
		models = {},
		model_redirects = {},
		five_hour_threshold = nil,
		weekly_threshold = nil,
		five_hour_quota_tokens = opts.five_hour_quota_tokens,
		weekly_quota_tokens = opts.weekly_quota_tokens,
		usage_source = opts.usage_source or {five_hour = "upstream", weekly = "upstream"},
		poll_interval = opts.poll_interval,
	}
end

---@return ai.router.UsageRepo
---@return ai.router.WindowsRepo
---@return ai.router.RouterDatabase
local function open()
	local storage = RouterDatabase(LjsqliteDatabase())
	storage.path = ":memory:"
	storage:open()
	return UsageRepo(storage.models), WindowsRepo(storage.models), storage
end

---@param t testing.T
function test.parses_openai_usage_windows(t)
	local windows = UsageMonitor.parseOpenAIUsage({
		rate_limit = {
			primary_window = {used_percent = 42.5, reset_at = 1780000000},
			secondary_window = {used_percent = 5, reset_at = 1780100000},
		},
	})
	t:eq(windows.five_hour.used_percent, 42.5)
	t:eq(windows.five_hour.reset_at, 1780000000)
	t:eq(windows.weekly.used_percent, 5)

	t:eq(UsageMonitor.parseOpenAIUsage({}).five_hour, nil)
	t:eq(UsageMonitor.parseOpenAIUsage({rate_limit = {primary_window = {}}}).five_hour.used_percent, nil)
end

---@param t testing.T
function test.parses_zai_usage_windows(t)
	local windows = UsageMonitor.parseZaiUsage({
		level = "lite",
		limits = {
			{type = "CREDIT_LIMIT", unit = 3, number = 5, usage = 2000, currentValue = 128,
				remaining = 1871, percentage = 6, nextResetTime = 1791236689140},
			{type = "CREDIT_LIMIT", unit = 6, number = 1, usage = 10000, currentValue = 1104,
				remaining = 8895, percentage = 11, nextResetTime = 1791535121983},
			{type = "OTHER", unit = 9, number = 2, percentage = 50},
		},
	})
	t:eq(windows.five_hour.used_percent, 6)
	t:eq(windows.five_hour.used_tokens, 128)
	t:eq(windows.five_hour.quota_tokens, 2000)
	t:eq(windows.five_hour.reset_at, 1791236689)
	t:eq(windows.weekly.used_percent, 11)
	t:eq(windows.weekly.quota_tokens, 10000)
	t:eq(windows.weekly, nil or windows.weekly)
	t:eq(windows.monthly, nil)
	t:eq(UsageMonitor.parseZaiUsage({}).five_hour, nil)
end

---@param t testing.T
function test.upstream_poll_updates_state_and_persists(t)
	local usage_repo, windows_repo, storage = open()
	local monitor = UsageMonitor({
		usage_repo = usage_repo,
		windows_repo = windows_repo,
		logger = function() end,
	})
	monitor:setSubscriptions({subState({id = 7, name = "zai-1"})}, {
		[7] = function()
			return {
				level = "lite",
				limits = {
					{type = "CREDIT_LIMIT", unit = 3, number = 5, usage = 2000, currentValue = 500,
						percentage = 25, nextResetTime = 1791236689140},
					{type = "CREDIT_LIMIT", unit = 6, number = 1, usage = 10000, currentValue = 1000,
						percentage = 10, nextResetTime = 1791535121983},
				},
			}
		end,
	})
	monitor:update(1000)
	t:eq(monitor.windows[7].five_hour.used_percent, 25)
	t:eq(monitor.windows[7].five_hour.source, "upstream")
	t:eq(monitor.windows[7].weekly.used_percent, 10)
	local snapshot = windows_repo:snapshot(7)
	t:eq(snapshot.five_hour.used_percent, 25)
	t:eq(snapshot.five_hour.quota_tokens, 2000)
	t:eq(snapshot.weekly.reset_at, 1791535121)

	-- second update within the interval does not poll again
	monitor:setSubscriptions({subState({id = 7, name = "zai-1"})}, {
		[7] = function() error("must not poll") end,
	})
	monitor:update(1010)
	t:eq(monitor.windows[7].five_hour.used_percent, 25)

	-- refresh forces a poll and a failed fetch keeps the previous state
	monitor:refresh(7, 1020)
	t:eq(monitor.windows[7].five_hour.used_percent, 25)
	storage:close()
end

---@param t testing.T
function test.local_counting_uses_aggregates(t)
	local usage_repo, windows_repo, storage = open()
	usage_repo:record(3600, "alice", 200, "m", "u", "local-1",
		{input_tokens = 600, output_tokens = 200, cached_input_tokens = 0, estimated = false})
	local monitor = UsageMonitor({
		usage_repo = usage_repo,
		windows_repo = windows_repo,
		logger = function() end,
	})
	monitor:setSubscriptions({subState({
		id = 3,
		name = "local-1",
		kind = "openai_compat",
		usage_source = {five_hour = "local", weekly = "local"},
		five_hour_quota_tokens = 1600,
	})}, {})
	monitor:update(4000)
	t:eq(monitor.windows[3].five_hour.used_percent, 50)
	t:eq(monitor.windows[3].five_hour.used_tokens, 800)
	t:eq(monitor.windows[3].five_hour.source, "local")
	-- no weekly quota configured: no weekly state
	t:eq(monitor.windows[3].weekly, nil)
	storage:close()
end

---@param t testing.T
function test.disabled_subscriptions_drop_state(t)
	local usage_repo, windows_repo, storage = open()
	local monitor = UsageMonitor({
		usage_repo = usage_repo,
		windows_repo = windows_repo,
		logger = function() end,
	})
	monitor:setSubscriptions({subState({id = 1})}, {
		[1] = function()
			return {limits = {{type = "CREDIT_LIMIT", unit = 3, number = 5, usage = 100,
				currentValue = 10, percentage = 10}}}
		end,
	})
	monitor:update(1000)
	t:assert(monitor.windows[1].five_hour)

	monitor:setSubscriptions({subState({id = 1, enabled = false})}, {})
	monitor:update(2000)
	t:eq(monitor.windows[1], nil)

	monitor:setSubscriptions({subState({id = 1})}, {})
	monitor:update(3000)
	t:eq(monitor.windows[1], nil)
	storage:close()
end

return test
