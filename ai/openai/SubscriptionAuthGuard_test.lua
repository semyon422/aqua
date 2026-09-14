local SubscriptionAuthGuard = require("ai.openai.SubscriptionAuthGuard")

local test = {}

---@param t testing.T
function test.releases_guard_after_authentication_exception(t)
	local calls = 0
	local auth = {
		getAccess = function()
			calls = calls + 1
			if calls == 1 then error("refresh failed") end
			return "access", "account"
		end,
	}
	local scheduler = {sleep = function() error("guard remained locked") end}
	local guard = SubscriptionAuthGuard(auth --[[@as openai.ISubscriptionAuth]], scheduler --[[@as web.CosocketScheduler]])

	local ok, err = pcall(guard.getAccess, guard)
	t:eq(ok, false)
	t:assert(tostring(err):find("refresh failed", 1, true))
	t:eq(guard.busy, false)
	t:tdeq({guard:getAccess()}, {"access", "account"})
end

return test
