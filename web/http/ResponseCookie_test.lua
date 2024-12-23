local ResponseCookie = require("web.http.ResponseCookie")

local test = {}

---@param t testing.T
function test.basic(t)
	local res_cookie = ResponseCookie("a=1; Domain=example.com; Secure; HttpOnly")

	t:eq(res_cookie:get("Domain"), "example.com")
	t:eq(res_cookie:get("Path"), nil)
	t:eq(res_cookie:get("Secure"), nil)

	t:eq(res_cookie:exists("Domain"), true)
	t:eq(res_cookie:exists("Secure"), true)
	t:eq(res_cookie:exists("Partitioned"), false)

	t:eq(tostring(res_cookie), "a=1; Domain=example%2ecom; Secure; HttpOnly")

	res_cookie:set("Partitioned")
	res_cookie:set("Path", "/")

	t:eq(tostring(res_cookie), "a=1; Domain=example%2ecom; Secure; HttpOnly; Partitioned; Path=%2f")
end

return test
