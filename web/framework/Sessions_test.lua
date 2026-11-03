local Sessions = require("web.framework.Sessions")
local Headers = require("web.http.Headers")

local test = {}

---@param t testing.T
function test.encode_decode(t)
	local sessions = Sessions("cookie_name", "secret key")

	local session = {hello = "world"}

	local encoded = sessions:encode(session)
	local decoded = sessions:decode(encoded)

	t:tdeq(decoded, session)
	t:assert(session.csrf_token ~= nil, "CSRF token not generated")
end

---@param t testing.T
function test.csrf_validation(t)
	local sessions = Sessions("cookie_name", "secret key")
	---@type {[string]: any}
	local session = {user_id = 123}

	-- Generates token on encode
	sessions:encode(session)
	local token = session.csrf_token
	t:assert(token ~= nil)

	t:assert(sessions:validate_csrf_token(session, token))
	t:assert(not sessions:validate_csrf_token(session, "wrong_token"))
	t:assert(not sessions:validate_csrf_token({}, token))
end

---@param t testing.T
function test.set_cookie_attributes(t)
	local sessions = Sessions("router_admin", "secret key")
	local headers = Headers()
	sessions:set(headers, {}, 315360000)
	local set_cookie = assert(headers:get("Set-Cookie"))
	t:assert(set_cookie:find("Max-Age=315360000", 1, true), set_cookie)
	t:assert(set_cookie:find("HttpOnly", 1, true), set_cookie)
	t:assert(set_cookie:find("SameSite=Lax", 1, true), set_cookie)
	t:assert(set_cookie:find("Path=/", 1, true), set_cookie)
	local headers2 = Headers()
	sessions:set(headers2, {})
	set_cookie = assert(headers2:get("Set-Cookie"))
	t:eq(set_cookie:find("Max-Age", 1, true), nil)
end

return test
