local class = require("class")

---@class ai.router.WindowState
---@field used_percent number?
---@field updated_at number unix seconds of the monitor snapshot

---@alias ai.router.Windows {[integer]: {[string]: ai.router.WindowState}}

---@alias ai.router.Cooldowns {[integer]: number} subscription_id -> cooldown expiry (unix seconds)

---@class ai.router.Candidate
---@field subscription ai.router.SubscriptionState
---@field model string public chain entry requested
---@field upstream_model string model name sent upstream after the permanent redirect

-- Pure routing logic over an immutable catalog state. Window and cooldown
-- data are passed per call so selection is deterministic and testable.
---@class ai.router.Router
---@operator call: ai.router.Router
---@field state ai.router.CatalogState
---@field staleness number seconds; older window data never depletes
local Router = class()

Router.default_staleness = 120

local window_names = {"five_hour", "weekly"}

---@param subscription ai.router.SubscriptionState
---@param window "five_hour"|"weekly"
---@return number? threshold
local function windowThreshold(subscription, window)
	if window == "five_hour" then
		return subscription.five_hour_threshold
	end
	return subscription.weekly_threshold
end

---@param options {state: ai.router.CatalogState, staleness: number?}
function Router:new(options)
	self.state = options.state
	self.staleness = options.staleness or Router.default_staleness
end

-- Expands a public model name to its ordered chain: an alias resolves to its
-- configured targets, a concrete model to itself.
---@param public_model string
---@return string[]? chain
function Router:resolveChain(public_model)
	---@type string[]
	local alias = self.state.alias_models[public_model]
	if alias then
		---@type string[]
		local chain = {}
		for i, entry in ipairs(alias) do
			chain[i] = entry
		end
		return chain
	end
	if self.state.concrete_models[public_model] then
		return {public_model}
	end
	return nil
end

-- All serving candidates in preference order: chain entries in order, then
-- subscriptions by (priority, id). Disabled subscriptions are skipped. The
-- list is walked by the server for the initial pick and for failover.
---@param public_model string
---@return ai.router.Candidate[]? candidates
---@return string? error_message
function Router:candidates(public_model)
	local chain = self:resolveChain(public_model)
	if not chain then
		return nil, "unknown model: " .. tostring(public_model)
	end
	---@type ai.router.Candidate[]
	local candidates = {}
	for _, model in ipairs(chain) do
		for _, subscription in ipairs(self.state.subscriptions) do
			if subscription.enabled and subscription.models[model] then
				---@type ai.router.Candidate
				local candidate = {
					subscription = subscription,
					model = model,
					upstream_model = subscription.model_redirects[model] or model,
				}
				table.insert(candidates, candidate)
			end
		end
	end
	return candidates
end

---@param subscription ai.router.SubscriptionState
---@param windows ai.router.Windows
---@param now number
---@return ai.router.WindowState?
local function freshWindow(subscription, windows, now, staleness, window)
	local state = windows[subscription.id]
	local ws = state and state[window]
	if not ws then return nil end
	if now - ws.updated_at > staleness then return nil end
	return ws
end

-- A subscription is depleted when any monitored window with a configured
-- threshold is filled at or above it. Missing or stale data never depletes.
---@param subscription ai.router.SubscriptionState
---@param windows ai.router.Windows
---@param now number
---@return boolean depleted
function Router:isDepleted(subscription, windows, now)
	for _, window in ipairs(window_names) do
		local threshold = windowThreshold(subscription, window)
		if threshold ~= nil then
			local ws = freshWindow(subscription, windows, now, self.staleness, window)
			if ws and ws.used_percent ~= nil and ws.used_percent >= threshold then
				return true
			end
		end
	end
	return false
end

-- Maximum fresh window fill, used to rank last-resort candidates. Missing or
-- stale data counts as zero fill.
---@param subscription ai.router.SubscriptionState
---@param windows ai.router.Windows
---@param now number
---@return number fill
function Router:maxFill(subscription, windows, now)
	local fill = 0
	for _, window in ipairs(window_names) do
		local ws = freshWindow(subscription, windows, now, self.staleness, window)
		if ws and ws.used_percent ~= nil and ws.used_percent > fill then
			fill = ws.used_percent
		end
	end
	return fill
end

-- Picks the first candidate at or after `start` that is not cooling down and
-- not depleted. If every remaining candidate is depleted, returns the least
-- depleted non-cooling one instead of failing; cooling-down subscriptions are
-- never used as a last resort.
---@param candidates ai.router.Candidate[]
---@param start integer 1-based index to start from, for failover walks
---@param windows ai.router.Windows
---@param cooldowns ai.router.Cooldowns?
---@param now number
---@return integer? index
---@return ai.router.Candidate? candidate
---@return "available"|"depleted"|"unavailable" reason
function Router:select(candidates, start, windows, cooldowns, now)
	---@type integer?
	local best_index
	---@type number?
	local best_fill
	for i = start, #candidates do
		local candidate = candidates[i]
		local subscription = candidate.subscription
		local cooldown_until = cooldowns and cooldowns[subscription.id]
		if cooldown_until == nil or cooldown_until <= now then
			if not self:isDepleted(subscription, windows, now) then
				return i, candidate, "available"
			end
			local fill = self:maxFill(subscription, windows, now)
			if best_fill == nil or fill < best_fill then
				best_index, best_fill = i, fill
			end
		end
	end
	if best_index then
		return best_index, candidates[best_index], "depleted"
	end
	return nil, nil, "unavailable"
end

return Router
