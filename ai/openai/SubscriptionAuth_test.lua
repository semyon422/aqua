local mime = require("mime")
local json = require("web.json")
local OpenAiSubscriptionAuth = require("ai.openai.SubscriptionAuth")

local test = {}

---@param account_id string
---@param expires_at integer?
---@return string
local function makeToken(account_id, expires_at)
	local claims = {
		["https://api.openai.com/auth"] = {chatgpt_account_id = account_id},
		exp = expires_at,
	}
	local payload = mime.b64(json.encode(claims)):gsub("=+$", ""):gsub("+", "-"):gsub("/", "_")
	return "header." .. payload .. ".signature"
end

local function makeCredentials()
	return {access_token = "", refresh_token = "", expires_at = 0, account_id = ""}
end

---@param t testing.T
function test.creates_pkce_login_and_opens_browser(t)
	local opened_url
	local started
	local server = {
		start = function(_, host, port)
			started = {host, port}
			return true
		end,
		stop = function() end,
	}
	local auth = OpenAiSubscriptionAuth({
		scheduler = {},
		credentials = makeCredentials(),
		save_credentials = function() end,
		open_url = function(url) opened_url = url return true end,
		request = function() error("not used") end,
		server_factory = function() return server --[[@as web.HttpServer]] end,
	})

	t:assert(auth:startLogin())
	t:eq(auth.status, "logging_in")
	t:eq(started[1], "127.0.0.1")
	t:eq(started[2], 1455)
	t:eq(opened_url, auth.auth_url)
	t:assert(opened_url:find("https://auth.openai.com/oauth/authorize?", 1, true))
	t:assert(opened_url:find("code_challenge_method=S256", 1, true))
	t:assert(opened_url:find("state=", 1, true))
end

---@param t testing.T
function test.exchanges_and_refreshes_tokens(t)
	local credentials = makeCredentials()
	local saved = 0
	local requests = {}
	local now = 1000
	local network = {
		request = function(_, url, body)
			table.insert(requests, {url = url, body = body})
			return {
				status = 200,
				body = json.encode({
					access_token = makeToken("account-1"),
					refresh_token = "refresh-1",
					expires_in = 3600,
				}),
			}
		end,
	}
	local auth = OpenAiSubscriptionAuth({
		scheduler = {},
		credentials = credentials,
		save_credentials = function() saved = saved + 1 end,
		open_url = function() return true end,
		request = function(url, body, options) return network:request(url, body, options) end,
		get_time = function() return now end,
	})
	auth.verifier = "verifier"

	t:assert(auth:exchangeAuthorizationCode("code"))
	t:eq(credentials.account_id, "account-1")
	t:eq(credentials.expires_at, 4600)
	t:eq(saved, 1)
	t:assert(requests[1].body:find("grant_type=authorization_code", 1, true))

	now = 4590
	local access, account_id = auth:getAccess()
	t:eq(access, credentials.access_token)
	t:eq(account_id, "account-1")
	t:eq(saved, 2)
	t:assert(requests[2].body:find("grant_type=refresh_token", 1, true))
end

---@param t testing.T
function test.requires_login_without_refresh_token(t)
	local auth = OpenAiSubscriptionAuth({
		scheduler = {},
		credentials = makeCredentials(),
		save_credentials = function() end,
		open_url = function() return true end,
		request = function() error("not used") end,
	})
	local access, _, err = auth:getAccess()
	t:eq(access, nil)
	t:eq(err, "OpenAI login is required")
	t:eq(auth.status, "error")
end

---@param t testing.T
function test.callback_validates_state_and_decodes_authorization_code(t)
	local exchanged_code
	local stopped = 0
	local auth = OpenAiSubscriptionAuth({
		scheduler = {},
		credentials = makeCredentials(),
		save_credentials = function() end,
		open_url = function() return true end,
		request = function() error("not used") end,
	})
	auth.state = "expected state"
	auth.verifier = "verifier"
	auth.server = {stop = function() stopped = stopped + 1 end} --[[@as web.HttpServer]]
	auth.exchangeAuthorizationCode = function(_, code)
		exchanged_code = code
		auth:setStatus("authenticated")
		return true
	end
	local response
	response = {
		headers = {set = function() end},
		set_length = function() end,
		send = function(_, body) response.body = body end,
	}
	auth:handleCallback({method = "GET", uri = "/auth/callback?state=expected+state&code=code%2Bvalue"} --[[@as web.Request]], response --[[@as web.Response]])

	t:eq(exchanged_code, "code+value")
	t:eq(response.status, 200)
	t:assert(response.body:find("login complete", 1, true))
	t:eq(stopped, 1)
	t:eq(auth.server, nil)
end

---@param t testing.T
function test.logs_in_with_device_code_and_jwt_expiration(t)
	local credentials = makeCredentials()
	local now = 1000
	local requests = {}
	local polls = 0
	local shown_code
	local auth = OpenAiSubscriptionAuth({
		scheduler = {},
		credentials = credentials,
		save_credentials = function() end,
		open_url = function() return true end,
		get_time = function() return now end,
		sleep = function(seconds) now = now + seconds end,
		request = function(url, body)
			table.insert(requests, {url = url, body = body})
			if url == OpenAiSubscriptionAuth.device_code_url then
				return {
					status = 200,
					body = json.encode({device_auth_id = "device-1", user_code = "CODE-123", interval = "1"}),
				}
			elseif url == OpenAiSubscriptionAuth.device_token_url then
				polls = polls + 1
				if polls == 1 then return {status = 404, body = ""} end
				return {
					status = 200,
					body = json.encode({
						authorization_code = "authorization-1",
						code_challenge = "challenge-1",
						code_verifier = "verifier-1",
					}),
				}
			elseif url == OpenAiSubscriptionAuth.token_url then
				return {
					status = 200,
					body = json.encode({
						access_token = makeToken("account-device", 5000),
						refresh_token = "refresh-device",
					}),
				}
			end
			error("unexpected URL: " .. url)
		end,
	})

	t:assert(auth:loginWithDeviceCode(function(device_code) shown_code = device_code end))
	t:eq(shown_code.verification_url, "https://auth.openai.com/codex/device")
	t:eq(shown_code.user_code, "CODE-123")
	t:eq(polls, 2)
	t:eq(credentials.account_id, "account-device")
	t:eq(credentials.expires_at, 5000)
	t:eq(auth.status, "authenticated")
	t:assert(requests[4].body:find("code_verifier=verifier%2d1", 1, true))
	t:assert(requests[4].body:find("redirect_uri=https%3a%2f%2fauth%2eopenai%2ecom%2fdeviceauth%2fcallback", 1, true))
end

return test
