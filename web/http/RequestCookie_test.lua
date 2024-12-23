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

return test
