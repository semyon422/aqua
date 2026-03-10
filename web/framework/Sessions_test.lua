local Sessions = require("web.framework.Sessions")

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
	local session = {user_id = 123}

	-- Generates token on encode
	sessions:encode(session)
	local token = session.csrf_token
	t:assert(token ~= nil)

	t:assert(sessions:validate_csrf_token(session, token))
	t:assert(not sessions:validate_csrf_token(session, "wrong_token"))
	t:assert(not sessions:validate_csrf_token({}, token))
end

return test
