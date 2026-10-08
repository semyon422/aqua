local class = require("class")
local json = require("web.json")

---@class ai.router.ModelPrice
---@field input number? USD per million input tokens
---@field output number? USD per million output tokens
---@field cached_input number? USD per million cached input tokens

---@class ai.router.UsageCounters
---@field input_tokens integer
---@field output_tokens integer
---@field cached_input_tokens integer included in input_tokens
---@field estimated boolean provider counts were missing for at least one field

-- Hourly usage aggregates keyed by (bucket, user, model, upstream_model,
-- subscription) with one atomic upsert per completed request. `model` is the
-- public name the client requested, `upstream_model` is what was sent after
-- the subscription's permanent redirect, and prices are keyed by the upstream
-- model. No prompts, responses, keys, or addresses are persisted.
---@class ai.router.UsageRepo
---@operator call: ai.router.UsageRepo
---@field models rdb.Models
---@field prices {[string]: ai.router.ModelPrice}
local UsageRepo = class()

---@param models rdb.Models
---@param prices {[string]: ai.router.ModelPrice}?
function UsageRepo:new(models, prices)
	self.models = models
	self.prices = prices or {}
	for model, price in pairs(self.prices) do
		assert(type(model) == "string" and model ~= "", "model price requires a model name")
		---@type ("input"|"output"|"cached_input")[]
		local keys = {"input", "output", "cached_input"}
		for _, key in ipairs(keys) do
			---@type number?
			local value = price[key]
			assert(value == nil or (type(value) == "number" and value >= 0 and value < math.huge),
				"model price must be a finite non-negative number")
		end
	end
end

---@param now number
---@param user string
---@param status integer
---@param public_model string
---@param upstream_model string
---@param subscription string
---@param counters ai.router.UsageCounters
function UsageRepo:record(now, user, status, public_model, upstream_model, subscription, counters)
	assert(type(counters.input_tokens) == "number" and counters.input_tokens >= 0, "input_tokens must be a non-negative integer")
	assert(type(counters.output_tokens) == "number" and counters.output_tokens >= 0, "output_tokens must be a non-negative integer")
	local cached = counters.cached_input_tokens or 0
	assert(type(cached) == "number" and cached >= 0 and cached % 1 == 0 and cached <= counters.input_tokens,
		"cached token count must be an integer between zero and input tokens")
	self.models.router_usage_models.orm:query([[INSERT INTO router_usage_models
		(bucket, user, model, upstream_model, subscription, requests, errors,
			input_tokens, output_tokens, cached_input_tokens, estimated_requests)
		VALUES (?, ?, ?, ?, ?, 1, ?, ?, ?, ?, ?)
		ON CONFLICT(bucket, user, model, upstream_model, subscription) DO UPDATE SET
		requests = requests + 1, errors = errors + excluded.errors,
		input_tokens = input_tokens + excluded.input_tokens,
		output_tokens = output_tokens + excluded.output_tokens,
		cached_input_tokens = cached_input_tokens + excluded.cached_input_tokens,
		estimated_requests = estimated_requests + excluded.estimated_requests]],
		{math.floor(now / 3600) * 3600, user, public_model, upstream_model, subscription,
			status >= 400 and 1 or 0,
			counters.input_tokens, counters.output_tokens, cached,
			counters.estimated and 1 or 0})
end

---@param now number
---@return table
function UsageRepo:history(now)
	local last = math.floor(now / 3600) * 3600
	local first = last - 167 * 3600
	local rows = self.models.router_usage_models:select({bucket__gte = first, bucket__lte = last}, {
		order = {"bucket", "user", "model", "upstream_model", "subscription"},
	})
	for _, row in ipairs(rows) do
		local price = self.prices[row.upstream_model]
		row.cache_savings_usd = row.cached_input_tokens
			* ((price and price.input or 0) - (price and price.cached_input or 0)) / 1000000
		row.cost_usd = ((row.input_tokens - row.cached_input_tokens) * (price and price.input or 0)
			+ row.cached_input_tokens * (price and price.cached_input or 0)
			+ row.output_tokens * (price and price.output or 0)) / 1000000
	end
	return {bucket_seconds = 3600, first_bucket = first, last_bucket = last,
		generated_at = now, currency = "USD", rows = json.array(rows)}
end

-- Input plus output tokens served by a subscription since the hour bucket
-- containing `now - window_seconds`. Hour-bucket granularity is an estimate
-- used for local limit-window counting.
---@param subscription string
---@param now number
---@param window_seconds integer
---@return integer tokens
function UsageRepo:subscriptionTokens(subscription, now, window_seconds)
	local since = math.floor((now - window_seconds) / 3600) * 3600
	local rows = self.models.router_usage_models.orm:query(
		[[SELECT COALESCE(SUM(input_tokens + output_tokens), 0) AS tokens
			FROM router_usage_models WHERE subscription = ? AND bucket >= ?]],
		{subscription, since}
	)
	return tonumber(rows[1].tokens) or 0
end

return UsageRepo
