local SetCookieString = require("web.http.SetCookieString")
local RequestCookie = require("web.http.RequestCookie")
local Sessions = require("web.framework.Sessions")
local Headers = require("web.http.Headers")

local test = {}

---@param t testing.T
function test.basic(t)
	local res_cookie = SetCookieString("a=1; Domain=example.com; Secure")

	t:eq(res_cookie:get("Domain"), "example.com")
	t:eq(res_cookie:get("Path"), nil)
	t:eq(res_cookie:get("Secure"), "")

	t:eq(tostring(res_cookie), "a=1; Domain=example.com; Secure")

	res_cookie:add("HttpOnly")
	res_cookie:add("Path", "/")

	t:eq(tostring(res_cookie), "a=1; Domain=example.com; Secure; HttpOnly; Path=/")
end

---@param t testing.T
function test.literal_path_and_attribute_validation(t)
	local cookie = SetCookieString("a=1")
	cookie:add("Path", "/admin/with%20space")
	cookie:add("SameSite", "Lax")
	t:eq(tostring(cookie), "a=1; Path=/admin/with%20space; SameSite=Lax")
	cookie:add("Path", "/; Secure")
	t:has_error(function() return tostring(cookie) end)
end

---@param t testing.T
function test.dates_and_relative_max_age(t)
	local cookie = SetCookieString("sid=x; Expires=Sunday, 06-Nov-94 08:49:37 GMT; Max-Age=60")
	t:eq(cookie:get("expires"), "Sun, 06 Nov 1994 08:49:37 GMT")
	t:eq(cookie:get("MAX-AGE"), "60")
	t:eq(tostring(cookie), "sid=x; Expires=Sun, 06 Nov 1994 08:49:37 GMT; Max-Age=60")
	cookie:add("Max-Age", -1)
	t:eq(cookie:get("Max-Age"), "0")
	cookie:add("Max-Age", "000120")
	t:eq(cookie:get("Max-Age"), "120")
	cookie:add("Max-Age", "999999999999999999999999999999")
	t:eq(cookie:get("Max-Age"), "999999999999999999999999999999")
	for _, invalid in ipairs({"-", "+1", "1.5", "60x", ""}) do
		local parsed = SetCookieString("a=1; Max-Age=" .. invalid)
		t:eq(parsed:get("Max-Age"), nil)
		t:eq(tostring(parsed), "a=1")
	end
	cookie:add("Expires", "invalid-date")
	t:eq(cookie:get("Expires"), "Sun, 06 Nov 1994 08:49:37 GMT")
end

---@param t testing.T
function test.parsing_and_duplicate_attributes(t)
	local cookie = SetCookieString(' \tsid \t= \t"a=+/%20" \t; domain=.EXAMPLE.com; pAth=/a; PATH=/b; secure=ignored; SameSite=lax; Priority=High;')
	t:eq(cookie:get("domain"), "example.com")
	t:eq(cookie:get("Path"), "/b")
	t:eq(tostring(cookie), 'sid="a=+/%20"; Domain=example.com; Path=/b; Secure; SameSite=Lax; Priority=High')
	t:eq(#cookie.attribute_list, 5)
	for _, input in ipairs({"a=1; Path=", "a=1; Path=relative", "a=1; Domain=", "a=1; SameSite=invalid", "a=1; Expires=bad"}) do
		t:eq(tostring(SetCookieString(input)), "a=1")
	end
	t:eq(tostring(SetCookieString("a=1;")), "a=1")
	t:eq(tostring(SetCookieString("empty=")), "empty=")
	for _, input in ipairs({"", "garbage", "=value", " \t=value"}) do
		local parsed = SetCookieString(input)
		t:eq(parsed.ignore, true)
		t:has_error(function() return tostring(parsed) end)
	end
end

---@param t testing.T
function test.rejects_invalid_output(t)
	for _, name in ipairs({"", "a b", "a=b", "a;Secure", "a\r\n", "a\127", "имя"}) do
		local cookie = SetCookieString()
		cookie.name, cookie.value = name, "x"
		t:has_error(function() return tostring(cookie) end)
	end
	for _, value in ipairs({"a b", "a,b", "a;b", 'a"b', "a\\b", "\r\nInjected: x", "значение", '"a b"'}) do
		local cookie = SetCookieString()
		cookie.name, cookie.value = "sid", value
		t:has_error(function() return tostring(cookie) end)
	end
	for _, domain in ipairs({"example%2ecom", "a..b", "example.com.", "-a.com", "пример.рф"}) do
		local cookie = SetCookieString("sid=x")
		cookie:add("Domain", domain)
		t:has_error(function() return tostring(cookie) end)
	end
	for _, value in ipairs({"/bad;Secure", "/bad\r\n", "/bad\127", "/путь"}) do
		local cookie = SetCookieString("sid=x")
		cookie:add("Path", value)
		t:has_error(function() return tostring(cookie) end)
	end
end

---@param t testing.T
function test.session_cookie_roundtrip(t)
	local sessions = Sessions("sid", "test-cookie-secret", true)
	local response_headers = Headers()
	local session = {user_id = 123}
	sessions:set(response_headers, session)
	local header = assert(response_headers:get("Set-Cookie"))
	local response_cookie = SetCookieString(header)
	t:eq(response_cookie:get("Path"), "/")
	t:eq(response_cookie:get("Domain"), nil)
	t:eq(response_cookie:get("SameSite"), "Lax")
	t:eq(response_cookie:get("HttpOnly"), "")
	t:eq(response_cookie:get("Secure"), "")
	t:eq(tostring(response_cookie), header)
	local request_cookie = RequestCookie()
	request_cookie:set(response_cookie.name, response_cookie.value)
	local request_headers = Headers()
	request_headers:set("Cookie", tostring(request_cookie))
	t:tdeq(sessions:get(request_headers), session)
end

return test
