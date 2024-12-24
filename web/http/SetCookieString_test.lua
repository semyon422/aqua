local SetCookieString = require("web.http.SetCookieString")

local test = {}

---@param t testing.T
function test.basic(t)
	local res_cookie = SetCookieString("a=1; Domain=example.com; Secure")

	t:eq(res_cookie:get("Domain"), "example.com")
	t:eq(res_cookie:get("Path"), nil)
	t:eq(res_cookie:get("Secure"), "")

	t:eq(tostring(res_cookie), "a=1; Domain=example%2ecom; Secure")

	res_cookie:add("HttpOnly")
	res_cookie:add("Path", "/")

	t:eq(tostring(res_cookie), "a=1; Domain=example%2ecom; Secure; HttpOnly; Path=%2f")
end

return test
