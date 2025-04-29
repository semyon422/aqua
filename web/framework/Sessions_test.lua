local Sessions = require("web.framework.Sessions")

local test = {}

---@param t testing.T
function test.encode_decode(t)
	local sessions = Sessions("cookie_name", "secret key")

	local session = {hello = "world"}

	t:tdeq(sessions:decode(sessions:encode(session)), session)
end

return test
