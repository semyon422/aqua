local UsageRepo = require("ai.router.UsageRepo")
local RouterDatabase = require("ai.router.storage.RouterDatabase")
local LjsqliteDatabase = require("rdb.db.LjsqliteDatabase")

local test = {}

---@return ai.router.UsageRepo
---@return ai.router.RouterDatabase
local function open(prices)
	local storage = RouterDatabase(LjsqliteDatabase())
	storage.path = ":memory:"
	storage:open()
	return UsageRepo(storage.models, prices), storage
end

---@param t testing.T
function test.record_upserts_by_all_dimensions(t)
	local repo, storage = open()
	repo:record(3600, "alice", 200, "lite", "glm-5.3", "zai-1",
		{input_tokens = 10, output_tokens = 2, cached_input_tokens = 4, estimated = false})
	repo:record(3600, "alice", 200, "lite", "glm-5.3", "zai-1",
		{input_tokens = 5, output_tokens = 1, cached_input_tokens = 0, estimated = false})
	repo:record(3600, "alice", 500, "lite", "glm-5.3-high", "zai-2",
		{input_tokens = 1, output_tokens = 1, cached_input_tokens = 0, estimated = true})
	repo:record(3600, "bob", 200, "lite", "glm-5.3", "zai-1",
		{input_tokens = 3, output_tokens = 0, cached_input_tokens = 0, estimated = false})
	repo:record(7200, "alice", 200, "lite", "glm-5.3", "zai-1",
		{input_tokens = 7, output_tokens = 3, cached_input_tokens = 0, estimated = false})

	---@type {rows: any[]}
	local history = repo:history(7200)
	local rows = history.rows
	t:eq(#rows, 4)
	local row = rows[1]
	t:eq(row.user, "alice")
	t:eq(row.model, "lite")
	t:eq(row.upstream_model, "glm-5.3")
	t:eq(row.subscription, "zai-1")
	t:eq(row.requests, 2)
	t:eq(row.errors, 0)
	t:eq(row.input_tokens, 15)
	t:eq(row.output_tokens, 3)
	t:eq(row.cached_input_tokens, 4)
	t:eq(row.estimated_requests, 0)
	t:eq(rows[2].upstream_model, "glm-5.3-high")
	t:eq(rows[2].errors, 1)
	t:eq(rows[2].estimated_requests, 1)

	t:has_error(function()
		repo:record(3600, "alice", 200, "lite", "glm-5.3", "zai-1",
			{input_tokens = 2, output_tokens = 0, cached_input_tokens = 3, estimated = false})
	end)
	storage:close()
end

---@param t testing.T
function test.history_costs_use_upstream_prices(t)
	local repo, storage = open({
		["glm-5.3"] = {input = 2, cached_input = 0.2, output = 8},
	})
	repo:record(3600, "alice", 200, "lite", "glm-5.3", "zai-1",
		{input_tokens = 1000000, output_tokens = 1000000, cached_input_tokens = 500000, estimated = false})

	---@type {bucket_seconds: integer, currency: string, first_bucket: integer, last_bucket: integer, rows: any[]}
	local history = repo:history(3600)
	t:eq(history.bucket_seconds, 3600)
	t:eq(history.currency, "USD")
	t:eq(history.first_bucket, 3600 - 167 * 3600)
	t:eq(history.last_bucket, 3600)
	local rows = history.rows
	local row = rows[1]
	t:eq(row.cost_usd, 0.5 * 2 + 0.5 * 0.2 + 8)
	t:eq(row.cache_savings_usd, 0.5 * (2 - 0.2))
	storage:close()
end

---@param t testing.T
function test.subscription_tokens_window(t)
	local repo, storage = open()
	-- buckets: 0, 3600, 7200, 10800
	for _, bucket in ipairs({0, 3600, 7200, 10800}) do
		repo:record(bucket, "alice", 200, "m", "u", "zai-1",
			{input_tokens = 10, output_tokens = 5, cached_input_tokens = 0, estimated = false})
	end
	repo:record(7200, "alice", 200, "m", "u", "zai-2",
		{input_tokens = 100, output_tokens = 0, cached_input_tokens = 0, estimated = false})

	-- now = 10800 + 3599, 2h window starts inside bucket 3600
	t:eq(repo:subscriptionTokens("zai-1", 14399, 2 * 3600), 45)
	-- full range
	t:eq(repo:subscriptionTokens("zai-1", 14399, 24 * 3600), 60)
	-- other subscription excluded
	t:eq(repo:subscriptionTokens("zai-2", 14399, 24 * 3600), 100)
	-- empty subscription
	t:eq(repo:subscriptionTokens("zai-3", 14399, 24 * 3600), 0)
	storage:close()
end

return test
