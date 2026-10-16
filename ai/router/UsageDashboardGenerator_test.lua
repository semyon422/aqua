local Generator = require("ai.router.UsageDashboardGenerator")

local test = {}
local counter_fields = {"requests", "errors", "input_tokens", "output_tokens", "cached_input_tokens", "estimated_requests", "cost_usd"}

---@param bucket integer
---@param user string
---@param model string?
---@param channel string?
---@return ai.router.UsageRow
local function row(bucket, user, model, channel)
	return {bucket = bucket * 3600, user = user, model = model or "m", upstream_model = "upstream",
		channel = channel or "c", requests = 1, errors = 0, input_tokens = 10, output_tokens = 5,
		cached_input_tokens = 3, estimated_requests = 0, cost_usd = 0.25, cache_savings_usd = 0.1}
end

---@param rows ai.router.UsageRow[]
---@return ai.router.UsageHistory
local function history(rows)
	return {bucket_seconds = 3600, first_bucket = 33 * 3600, last_bucket = 200 * 3600,
		generated_at = 200 * 3600 + 900, currency = "USD", rows = rows}
end

---@param t testing.T
function test.exact_bucket_boundaries_and_zero_filled_hours(t)
	local source = history({row(32, "too-old"), row(33, "first-week"), row(176, "older"),
		row(177, "first-day"), row(200, "current"), row(201, "future")})
	local day = Generator.generate(source, 24)
	t:eq(#day.timeline, 24)
	t:eq(day.timeline[1].bucket, 177 * 3600)
	t:eq(day.timeline[24].bucket, 200 * 3600)
	t:eq(day.timeline[1].requests, 1)
	t:eq(day.timeline[2].requests, 0)
	t:eq(day.timeline[24].requests, 1)
	t:eq(day.totals.requests, 2)
	local week = Generator.generate(source, 168)
	t:eq(#week.timeline, 168)
	t:eq(week.timeline[1].bucket, 33 * 3600)
	t:eq(week.timeline[1].requests, 1)
	t:eq(week.totals.requests, 4)
	t:has_error(function() Generator.generate(source, 25) end)
	t:eq(#source.rows, 6)
	t:eq(source.rows[1].requests, 1)
end

---@param t testing.T
function test.all_breakdowns_and_series_share_the_same_totals(t)
	local rows = {row(177, "alice"), row(200, "alice"), row(200, "bob", "alias", "other")}
	rows[3].errors = 1
	rows[3].estimated_requests = 1
	local data = Generator.generate(history(rows), 24)
	t:tdeq(data.totals, {requests = 3, errors = 1, input_tokens = 30, output_tokens = 15,
		cached_input_tokens = 9, estimated_requests = 1, cost_usd = 0.75})
	t:eq(data.sections[1].rows[1].key, "alice")
	t:eq(data.sections[1].rows[1].item.requests, 2)
	t:eq(data.sections[2].rows[2].key, "alias")
	for _, section in ipairs(data.sections) do
		for _, key in ipairs(counter_fields) do
			---@type number
			local value = data.totals[key]
			local sum = 0
			for _, entry in ipairs(section.rows) do
				---@type number
				local count = entry.item[key]
				sum = sum + count
			end
			t:eq(sum, value)
		end
	end
	for _, key in ipairs(counter_fields) do
		---@type number
		local value = data.totals[key]
		local sum = 0
		for _, hour in ipairs(data.timeline) do
			---@type number
			local count = hour[key]
			sum = sum + count
		end
		t:eq(sum, value)
	end
	t:eq(data.timeline[24].requests, 2)
	t:eq(data.timeline[24].errors, 1)
	t:eq(#data.charts[1].series, 2)
	t:eq(#data.charts[2].series, 3)
	t:eq(#data.charts[1].hours, 24)
	t:assert(data.charts[2].hours[24].label:find("Input: 20 · Output: 10 · Cached input: 6", 1, true))
end

---@param t testing.T
function test.empty_charts_are_finite_and_ties_are_deterministic(t)
	local empty = Generator.generate(history({}), 168)
	t:eq(empty.totals.requests, 0)
	for _, chart in ipairs(empty.charts) do
		t:eq(#chart.ticks, 2)
		for _, series in ipairs(chart.series) do
			t:eq(series.points:find("nan"), nil)
			t:eq(series.points:find("inf"), nil)
			local _, count = series.points:gsub(",180%.00", "")
			t:eq(count, 168)
		end
	end
	local sorted = Generator.generate(history({row(200, "zoe"), row(200, "amy")}), 24)
	t:eq(sorted.sections[1].rows[1].key, "amy")
	t:eq(sorted.sections[1].rows[2].key, "zoe")
end

return test
