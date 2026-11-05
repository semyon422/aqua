local json = require("web.json")
local UsageClient = require("ai.zai.UsageClient")

local test = {}

---@param t testing.T
function test.fetches_monitor_with_key_and_returns_raw_data_only(t)
	for _, url in ipairs({UsageClient.url, "https://example.test/quota"}) do
		local usage = assert(UsageClient.fetch({api_key = "key", url = url ~= UsageClient.url and url or nil,
			timeout = 12, request = function(request_url, body, options)
				t:eq(request_url, url)
				t:eq(body, nil)
				t:eq(options.method, "GET")
				t:eq(options.timeout, 12)
				t:tdeq(options.headers, {Accept = "application/json", Authorization = "Bearer key"})
				return {status = 200, body = [[{"code":200,"data":{"level":"lite","limits":[{"unit":3,"number":5,"percentage":0}],"extra":"retained"}}]]}
			end}))
		t:eq(usage.level, "lite")
		t:eq(usage.limits[1].percentage, 0)
		t:eq(usage.extra, "retained")
		t:eq(usage.data, nil)
		t:eq(usage.five_hour, nil)
	end
end

---@param t testing.T
function test.http_errors_keep_actual_status_without_copying_provider_body(t)
	for _, status in ipairs({401, 403, 429, 500, 503}) do
		local _, err, failure = UsageClient.fetch({api_key = "key", request = function()
			return {status = status, body = "SECRET provider body"}
		end})
		t:eq(err, "Z.ai usage request failed")
		t:eq(failure.status, status)
		t:eq(failure.code, "upstream_http")
		t:eq(json.encode(failure):find("SECRET", 1, true), nil)
	end
end

---@param t testing.T
function test.invalid_json_envelopes_and_missing_or_non_object_data_are_classified(t)
	for _, body in ipairs({"SECRET invalid JSON", "null", "[]", "123", '"text"', "false",
		"{}", '{"data":null}', '{"data":[]}', '{"data":"SECRET"}'}) do
		local usage, err, failure = UsageClient.fetch({api_key = "key", request = function()
			return {status = 200, body = body}
		end})
		t:eq(usage, nil)
		t:assert(err:find("invalid Z.ai usage response", 1, true))
		t:eq(failure.code, "invalid_response")
		t:eq(failure.status, nil)
		t:eq(json.encode(failure):find("SECRET", 1, true), nil)
	end
	-- The HTTP fetcher does not require any particular quota window.
	local usage = assert(UsageClient.fetch({api_key = "key", request = function()
		return {status = 200, body = '{"data":{}}'}
	end}))
	t:assert(json.isObject(usage))
end

---@param t testing.T
function test.transport_errors_have_no_fabricated_status_or_retry(t)
	local calls = 0
	local _, err, failure = UsageClient.fetch({api_key = "key", request = function()
		calls = calls + 1
		return nil, "SECRET transport error"
	end})
	t:eq(calls, 1)
	t:eq(err, "SECRET transport error")
	t:eq(failure.code, "transport")
	t:eq(failure.status, nil)
	t:eq(json.encode(failure):find("SECRET", 1, true), nil)
end

return test
