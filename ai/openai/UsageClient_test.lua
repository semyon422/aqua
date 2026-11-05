local json = require("web.json")
local Headers = require("web.http.Headers")
local UsageClient = require("ai.openai.UsageClient")

local test = {}

local function auth()
	return {getAccess = function() return "access", "account" end}
end

---@param t testing.T
function test.fetches_raw_usage_with_injected_auth_headers_and_network_options(t)
	local calls, ids = 0, {}
	local options = {auth = {getAccess = function()
		calls = calls + 1
		return "access-" .. calls, "account-" .. calls
	end}, url = "https://example.test/usage", originator = "ai-router", timeout = 12}
	options.request = function(url, body, request_options)
		t:eq(url, options.url)
		t:eq(body, nil)
		t:eq(request_options.method, "GET")
		t:eq(request_options.timeout, 12)
		local headers = request_options.headers
		t:eq(headers.Authorization, "Bearer access-" .. calls)
		t:eq(headers["ChatGPT-Account-Id"], "account-" .. calls)
		t:eq(headers.Accept, "application/json")
		t:eq(headers.Originator, options.originator or "openai-proxy")
		t:eq(headers["User-Agent"], headers.Originator)
		t:eq(#headers["x-client-request-id"], 16)
		table.insert(ids, headers["x-client-request-id"])
		return {status = 200, body = [[{"plan_type":"plus","rate_limit":{"primary_window":{"used_percent":0}},"credits":{"balance":7}}]]}
	end
	local usage = assert(UsageClient.fetch(options))
	t:eq(usage.plan_type, "plus")
	t:eq(usage.rate_limit.primary_window.used_percent, 0)
	t:eq(usage.credits.balance, 7)
	t:eq(usage.five_hour, nil)
	options.originator = nil
	assert(UsageClient.fetch(options))
	t:eq(calls, 2)
	t:assert(ids[1] ~= ids[2])
end

---@param t testing.T
function test.auth_failures_do_not_make_requests_or_expose_details_in_metadata(t)
	for _, result in ipairs({{}, {"access"}, {"access", ""}}) do
		local usage, _, failure = UsageClient.fetch({request = function() error("must not request") end,
			auth = {getAccess = function() return result[1], result[2], "SECRET auth failure" end}})
		t:eq(usage, nil)
		t:eq(failure.code, "auth")
		t:eq(failure.status, nil)
		t:eq(json.encode(failure):find("SECRET", 1, true), nil)
	end
end

---@param t testing.T
function test.http_errors_preserve_status_challenge_and_safe_request_identity(t)
	for _, status in ipairs({401, 403, 429, 500, 503}) do
		local headers = Headers():set("x-request-id", "upstream-id")
		if status == 403 then headers:set("cf-mitigated", "challenge") end
		local _, err, failure = UsageClient.fetch({auth = auth(), request = function(url)
			t:eq(url, UsageClient.url)
			return {status = status, body = "SECRET provider body", headers = headers}
		end})
		t:eq(failure.status, status)
		t:eq(failure.code, status == 403 and "cloudflare_challenge" or "upstream_http")
		t:eq(failure.request_id, "upstream-id")
		t:eq(err, "OpenAI usage request failed")
		t:eq(json.encode(failure):find("SECRET", 1, true), nil)
	end
	for _, id in ipairs({false, "", string.rep("x", 129), "bad\nheader"}) do
		local sent_id
		local _, _, failure = UsageClient.fetch({auth = auth(), request = function(_, _, options)
			sent_id = options.headers["x-client-request-id"]
			return {status = 429, body = "", headers = {get = function(_, key)
				if key == "x-request-id" then return id or nil end
			end}}
		end})
		t:eq(failure.request_id, sent_id)
	end
end

---@param t testing.T
function test.invalid_json_and_non_object_responses_are_classified(t)
	for _, body in ipairs({"SECRET invalid JSON", "null", "[]", "123", '"text"', "false"}) do
		local usage, err, failure = UsageClient.fetch({auth = auth(), request = function()
			return {status = 200, body = body}
		end})
		t:eq(usage, nil)
		t:eq(err, "invalid OpenAI usage response")
		t:eq(failure.code, "invalid_response")
		t:eq(failure.status, nil)
	end
	-- Window completeness is not the HTTP client's responsibility.
	local usage = assert(UsageClient.fetch({auth = auth(), request = function() return {status = 200, body = "{}"} end}))
	t:assert(json.isObject(usage))
end

---@param t testing.T
function test.transport_failures_have_no_fabricated_status_and_do_not_retry(t)
	local calls = 0
	local _, err, failure = UsageClient.fetch({auth = auth(), request = function()
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
