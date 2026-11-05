local json = require("web.json")
local UsageProtocol = require("ai.openai.UsageProtocol")

local test = {}

---@param t testing.T
function test.parses_known_windows_without_inventing_token_counts(t)
	local usage = json.decode([[{"rate_limit":{"primary_window":{"used_percent":42.5,"reset_at":1780000000},"secondary_window":{"used_percent":5,"reset_at":1780100000}},"credits":{"balance":100},"additional_rate_limits":[]}]])
	local before = json.encode(usage)
	local windows = UsageProtocol.parseWindows(usage)
	t:tdeq(windows, {
		five_hour = {used_percent = 42.5, reset_at = 1780000000},
		weekly = {used_percent = 5, reset_at = 1780100000},
	})
	t:eq(windows.five_hour.used_tokens, nil)
	t:eq(windows.five_hour.quota_tokens, nil)
	windows.five_hour.used_percent = 99
	t:eq(json.encode(usage), before)
end

---@param t testing.T
function test.accepts_partial_zero_and_over_quota_windows_without_clamping(t)
	local windows = UsageProtocol.parseWindows({rate_limit = {primary_window = {used_percent = 0, reset_at = 0}}})
	t:tdeq(windows, {five_hour = {used_percent = 0, reset_at = 0}})
	windows = UsageProtocol.parseWindows({rate_limit = {secondary_window = {used_percent = 110.5}}})
	t:tdeq(windows, {weekly = {used_percent = 110.5}})
	windows = UsageProtocol.parseWindows({rate_limit = {primary_window = {reset_at = 123}}})
	t:tdeq(windows, {five_hour = {reset_at = 123}})
	-- Completeness and staleness are the caller's policy, not parser errors.
	t:tdeq(UsageProtocol.parseWindows({rate_limit = {primary_window = {}}}), {five_hour = {}})
end

---@param t testing.T
function test.malformed_roots_and_containers_are_empty(t)
	t:tdeq(UsageProtocol.parseWindows(nil), {})
	for _, value in ipairs({false, 123, "SECRET", json.null, {}}) do
		t:tdeq(UsageProtocol.parseWindows(value), {})
		t:tdeq(UsageProtocol.parseWindows({rate_limit = value}), {})
		t:tdeq(UsageProtocol.parseWindows({rate_limit = {primary_window = value, secondary_window = value}}),
			type(value) == "table" and {five_hour = {}, weekly = {}} or {})
	end
	-- Responses token counters and the Z.ai RPC envelope are not quota windows.
	t:tdeq(UsageProtocol.parseWindows({input_tokens = 10, output_tokens = 2}), {})
	t:tdeq(UsageProtocol.parseWindows({data = {rate_limit = {primary_window = {used_percent = 10}}}}), {})
end

---@param t testing.T
function test.invalid_fields_are_omitted_without_coercion(t)
	for _, value in ipairs({false, "42", json.null, {}, 0 / 0, math.huge, -math.huge}) do
		local windows = UsageProtocol.parseWindows({rate_limit = {
			primary_window = {used_percent = value, reset_at = value},
			secondary_window = {used_percent = 10, reset_at = 123},
		}})
		t:tdeq(windows.five_hour, {})
		t:tdeq(windows.weekly, {used_percent = 10, reset_at = 123})
	end
end

return test
