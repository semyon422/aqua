local RequestCookie = require("web.http.RequestCookie")

local test = {}

---@param t testing.T
function test.basic(t)
	local req_cookie = RequestCookie()

	req_cookie:set("a", "1")
	req_cookie:set("b", "2")
	req_cookie:set("c", "3")

	t:eq(tostring(req_cookie), "a=1; b=2; c=3")

	req_cookie:unset("b")

	t:eq(tostring(req_cookie), "a=1; c=3")

	req_cookie = RequestCookie("a=1; b=2")

	t:eq(req_cookie:get("a"), "1")
	t:eq(req_cookie:get("b"), "2")
	t:eq(req_cookie:get("c"), nil)
end

---@param t testing.T
function test.literal_values_and_duplicates(t)
	local cookie = RequestCookie('sid=one; encoded=%2F%20; quoted="a=+/"; sid=two; empty=')
	t:eq(cookie:get("sid"), "two")
	t:tdeq(cookie:getAll("sid"), {"one", "two"})
	t:eq(cookie:get("encoded"), "%2F%20")
	t:eq(cookie:get("quoted"), '"a=+/"')
	t:eq(cookie:get("empty"), "")
	t:eq(tostring(cookie), 'sid=one; encoded=%2F%20; quoted="a=+/"; sid=two; empty=')
	cookie:set("sid", "three")
	t:tdeq(cookie:getAll("sid"), {"three"})
	t:eq(tostring(cookie), 'sid=three; encoded=%2F%20; quoted="a=+/"; empty=')
	cookie:unset("sid")
	t:tdeq(cookie:getAll("sid"), {})
	t:eq(cookie:get("sid"), nil)
	t:eq(tostring(cookie), 'encoded=%2F%20; quoted="a=+/"; empty=')
end

---@param t testing.T
function test.invalid_pairs_and_output(t)
	local cookie = RequestCookie('invalid; =empty-name; a b=x; bad=space value; good=ok; other=x\r\n; quoted="bad value"')
	t:eq(tostring(cookie), "good=ok")
	t:has_error(function() cookie:set("bad=name", "value") end)
	t:has_error(function() cookie:set("good", "bad;value") end)
	t:eq(cookie:get("good"), "ok")
	cookie:set("percent%name", "%2F=+")
	t:eq(tostring(cookie), "good=ok; percent%name=%2F=+")
end

return test
