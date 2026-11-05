local json = require("web.json")
local UsageProtocol = require("ai.zai.UsageProtocol")

local test = {}

---@param t testing.T
function test.parses_monitor_data_without_mutating_or_leaking_provider_fields(t)
	local data = json.decode([[{"level":"lite","limits":[
		{"type":"CREDIT_LIMIT","unit":3,"number":5,"usage":2000,"currentValue":128,"remaining":1871,"percentage":6,"nextResetTime":1791236689140},
		{"type":"CREDIT_LIMIT","unit":6,"number":1,"usage":10000,"currentValue":1104,"percentage":11,"nextResetTime":1791535121983},
		{"type":"OTHER","unit":9,"number":2,"percentage":50}]}]])
	local before = json.encode(data)
	local windows = UsageProtocol.parseWindows(data)
	t:tdeq(windows, {
		five_hour = {used_percent = 6, used_tokens = 128, quota_tokens = 2000, reset_at = 1791236689},
		weekly = {used_percent = 11, used_tokens = 1104, quota_tokens = 10000, reset_at = 1791535121},
	})
	windows.five_hour.used_percent = 99
	t:eq(json.encode(data), before)
end

---@param t testing.T
function test.accepts_partial_zero_and_over_quota_windows_without_clamping(t)
	t:tdeq(UsageProtocol.parseWindows({limits = {{unit = 3, number = 5,
		percentage = 0, currentValue = 0, usage = 0, nextResetTime = 0}}}),
		{five_hour = {used_percent = 0, used_tokens = 0, quota_tokens = 0, reset_at = 0}})
	t:tdeq(UsageProtocol.parseWindows({limits = {{unit = 6, number = 1, percentage = 110.5}}}),
		{weekly = {used_percent = 110.5}})
	t:tdeq(UsageProtocol.parseWindows({limits = {{unit = 3, number = 5, usage = 100}}}),
		{five_hour = {quota_tokens = 100}})
	-- The parser neither derives percentages from counts nor requires them.
	t:tdeq(UsageProtocol.parseWindows({limits = {{unit = 3, number = 5}}}), {five_hour = {}})
end

---@param t testing.T
function test.malformed_roots_containers_and_unrecognized_rows_are_ignored(t)
	t:tdeq(UsageProtocol.parseWindows(nil), {})
	for _, value in ipairs({false, 123, "SECRET", json.null, {}}) do
		t:tdeq(UsageProtocol.parseWindows(value), {})
		t:tdeq(UsageProtocol.parseWindows({limits = value}), {})
		t:tdeq(UsageProtocol.parseWindows({limits = {value}}), {})
	end
	t:tdeq(UsageProtocol.parseWindows({limits = {
		{unit = "3", number = 5, percentage = 1}, {unit = 3, number = "5", percentage = 1},
		{unit = 3, number = 1, percentage = 1}, {unit = 6, number = 5, percentage = 1},
	}}), {})
	-- The fetcher, not this parser, unwraps the RPC envelope.
	t:tdeq(UsageProtocol.parseWindows({data = {limits = {{unit = 3, number = 5, percentage = 10}}}}), {})
end

---@param t testing.T
function test.invalid_fields_are_omitted_without_coercion(t)
	for _, value in ipairs({false, "42", json.null, {}, 0 / 0, math.huge, -math.huge}) do
		local windows = UsageProtocol.parseWindows({limits = {
			{unit = 3, number = 5, percentage = value, currentValue = value, usage = value, nextResetTime = value},
			{unit = 6, number = 1, percentage = 10},
		}})
		t:tdeq(windows.five_hour, {})
		t:tdeq(windows.weekly, {used_percent = 10})
	end
end

---@param t testing.T
function test.last_recognized_row_wins_as_before(t)
	local windows = UsageProtocol.parseWindows({limits = {
		{unit = 3, number = 5, percentage = 10, usage = 100},
		{unit = 3, number = 5, percentage = 20},
	}})
	t:tdeq(windows, {five_hour = {used_percent = 20}})
end

return test
