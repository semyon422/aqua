local class = require("class")

---@class ai.router.WindowRow
---@field subscription_id integer
---@field window "five_hour"|"weekly"
---@field used_percent number?
---@field used_tokens integer?
---@field quota_tokens integer?
---@field reset_at integer?
---@field source "upstream"|"local"
---@field updated_at integer

-- Last-known usage-window snapshots per subscription. The monitor refreshes
-- them; fills survive restarts and the admin always has something to show.
---@class ai.router.WindowsRepo
---@operator call: ai.router.WindowsRepo
---@field models rdb.Models
local WindowsRepo = class()

WindowsRepo.windows = {
	five_hour = true,
	weekly = true,
}

WindowsRepo.sources = {
	upstream = true,
	["local"] = true,
}

---@param models rdb.Models
function WindowsRepo:new(models)
	self.models = models
end

---@class ai.router.WindowFields
---@field used_percent number?
---@field used_tokens integer?
---@field quota_tokens integer?
---@field reset_at integer?
---@field source "upstream"|"local"

---@param subscription_id integer
---@param window "five_hour"|"weekly"
---@param fields ai.router.WindowFields
---@param now integer
function WindowsRepo:save(subscription_id, window, fields, now)
	assert(WindowsRepo.windows[window], "unknown window: " .. tostring(window))
	assert(WindowsRepo.sources[fields.source], "unknown window source: " .. tostring(fields.source))
	local row = {
		subscription_id = subscription_id,
		window = window,
		used_percent = fields.used_percent,
		used_tokens = fields.used_tokens,
		quota_tokens = fields.quota_tokens,
		reset_at = fields.reset_at,
		source = fields.source,
		updated_at = now,
	}
	local existing = self.models.router_subscription_windows:find({
		subscription_id = subscription_id,
		window = window,
	})
	-- Snapshots replace the previous window state entirely so switching the
	-- data source cannot leave stale fields behind.
	if existing then
		self.models.router_subscription_windows:delete({
			subscription_id = subscription_id,
			window = window,
		})
	end
	self.models.router_subscription_windows:create(row)
end

---@param subscription_id integer
---@return {[string]: ai.router.WindowRow}
function WindowsRepo:snapshot(subscription_id)
	local rows = self.models.router_subscription_windows:select({subscription_id = subscription_id})
	---@cast rows ai.router.WindowRow[]
	---@type {[string]: ai.router.WindowRow}
	local windows = {}
	for _, row in ipairs(rows) do
		windows[row.window] = row
	end
	return windows
end

---@param subscription_id integer
function WindowsRepo:delete(subscription_id)
	self.models.router_subscription_windows:delete({subscription_id = subscription_id})
end

return WindowsRepo
