local OpenAILoginManager = require("ai.router.OpenAILoginManager")
local SubscriptionAuth = require("ai.openai.SubscriptionAuth")
local json = require("web.json")
---@type {b64: fun(value: string): string}
local mime = require("mime")

local test = {}

---@param t testing.T
function test.device_login_shares_auth_and_saves_credentials(t)
	local credentials = {access_token = "", refresh_token = "", expires_at = 0, account_id = ""}
	local saved, created, refreshed = 0, 0, 0
	local now = 1000
	local payload = mime.b64(json.encode({["https://api.openai.com/auth"] = {chatgpt_account_id = "account-1"}}))
	local access_token = "header." .. payload .. ".signature"
	local manager = OpenAILoginManager({
		scheduler = {},
		get_time = function() return now end,
		on_authenticated = function(id) refreshed = id end,
		create_auth = function(path)
			t:eq(path, "test-auth.lua")
			created = created + 1
			return SubscriptionAuth({
				scheduler = {},
				credentials = credentials,
				get_time = function() return now end,
				save_credentials = function() saved = saved + 1 end,
				open_url = function() return true end,
				sleep = function(seconds) now = now + seconds end,
				request = function(url)
					if url == SubscriptionAuth.device_code_url then
						return {status = 200, body = json.encode({device_auth_id = "device-private", user_code = "ABCD-EFGH", interval = 1})}
					elseif url == SubscriptionAuth.device_token_url then
						return {status = 200, body = json.encode({authorization_code = "code", code_verifier = "verifier"})}
					end
					return {status = 200, body = json.encode({access_token = access_token, refresh_token = "refresh-private", expires_in = 3600})}
				end,
			})
		end,
	})
	local guard = manager:getGuard("test-auth.lua")
	t:eq(manager:getState("test-auth.lua").status, "unauthenticated")
	manager:start({id = 7, kind = "openai", config = {auth_path = "test-auth.lua"}})
	t:eq(manager:getState("test-auth.lua").status, "authenticated")
	t:eq(manager:getState("test-auth.lua").user_code, nil)
	t:eq(manager:getGuard("test-auth.lua"), guard)
	local token, account_id = guard:getAccess()
	t:eq(token, access_token)
	t:eq(account_id, "account-1")
	t:eq(created, 1)
	t:eq(saved, 1)
	t:eq(refreshed, 7)
end

---@param t testing.T
function test.pending_login_code_and_failure_are_bounded(t)
	---@type thread?
	local thread
	local auth = SubscriptionAuth({
		scheduler = {},
		credentials = {access_token = "", refresh_token = "", expires_at = 0, account_id = ""},
		save_credentials = function() error("not used") end,
		open_url = function() return true end,
		request = function(url)
			if url == SubscriptionAuth.device_code_url then
				return {status = 200, body = json.encode({device_auth_id = "private-id", user_code = "ABCD-EFGH", interval = 1})}
			end
			coroutine.yield()
			error("private-token-error")
		end,
	})
	local manager = OpenAILoginManager({
		scheduler = {},
		create_auth = function() return auth end,
		get_time = function() return 100 end,
		spawn = function(callback)
			thread = coroutine.create(callback)
			assert(coroutine.resume(thread))
		end,
	})
	local row = {id = 1, kind = "openai", config = {auth_path = "test.lua"}}
	manager:start(row)
	local state = manager:getState("test.lua")
	t:eq(state.status, "logging_in")
	t:eq(state.user_code, "ABCD-EFGH")
	t:eq(state.verification_url, SubscriptionAuth.device_verification_url)
	t:eq(state.expires_at, 100 + SubscriptionAuth.device_login_timeout)
	t:eq(state.device_auth_id, nil)
	t:has_error(function() manager:start(row) end)
	t:assert(coroutine.resume(thread))
	state = manager:getState("test.lua")
	t:eq(state.status, "error")
	t:eq(state.user_code, nil)
	t:assert(not state.error:find("private", 1, true))
	t:has_error(function() manager:start({id = 2, kind = "openai_compat", config = {}}) end)
end

return test
