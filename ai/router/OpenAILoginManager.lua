local class = require("class")
local coext = require("coext")
local SubscriptionAuthGuard = require("ai.openai.SubscriptionAuthGuard")

---@class ai.router.OpenAILoginState
---@field status openai.SubscriptionAuthStatus
---@field verification_url string?
---@field user_code string?
---@field expires_at number?
---@field error string?

---@class ai.router.OpenAILoginEntry
---@field auth openai.SubscriptionAuth
---@field guard openai.SubscriptionAuthGuard
---@field state ai.router.OpenAILoginState

---@class ai.router.OpenAILoginManagerOptions
---@field scheduler web.CosocketScheduler
---@field create_auth fun(auth_path: string): openai.SubscriptionAuth
---@field on_authenticated (fun(subscription_id: integer))?
---@field spawn (fun(callback: fun()))?
---@field get_time (fun(): number)?

---@class ai.router.OpenAILoginManager
---@operator call: ai.router.OpenAILoginManager
---@field entries {[string]: ai.router.OpenAILoginEntry}
---@field create_auth fun(auth_path: string): openai.SubscriptionAuth
---@field scheduler web.CosocketScheduler
---@field spawn fun(callback: fun())
---@field get_time fun(): number
---@field on_authenticated (fun(subscription_id: integer))?
local OpenAILoginManager = class()

---@param options ai.router.OpenAILoginManagerOptions
function OpenAILoginManager:new(options)
	self.entries = {}
	self.scheduler = options.scheduler
	self.create_auth = options.create_auth
	self.on_authenticated = options.on_authenticated
	self.get_time = options.get_time or os.time
	self.spawn = options.spawn or function(callback)
		local thread = coext.detach(coroutine.create(callback))
		assert(coroutine.resume(thread))
	end
end

---@param auth_path string
---@return ai.router.OpenAILoginEntry
function OpenAILoginManager:entry(auth_path)
	local entry = self.entries[auth_path]
	if not entry then
		local auth = self.create_auth(auth_path)
		entry = {
			auth = auth,
			guard = SubscriptionAuthGuard(auth, self.scheduler),
			state = {status = auth:isAuthenticated() and "authenticated" or "unauthenticated"},
		}
		self.entries[auth_path] = entry
	end
	return entry
end

---@param auth_path string
---@return openai.SubscriptionAuthGuard
function OpenAILoginManager:getGuard(auth_path)
	return self:entry(auth_path).guard
end

---@param auth_path string
---@return ai.router.OpenAILoginState
function OpenAILoginManager:getState(auth_path)
	return self:entry(auth_path).state
end

---@param auth_path string
---@return boolean
function OpenAILoginManager:isLoggingIn(auth_path)
	return self:getState(auth_path).status == "logging_in"
end

---@param subscription ai.router.SubscriptionRow
function OpenAILoginManager:start(subscription)
	assert(subscription.kind == "openai", "device login requires an OpenAI subscription")
	local entry = self:entry(subscription.config.auth_path)
	assert(entry.state.status ~= "logging_in", "OpenAI login is already in progress")
	entry.state = {status = "logging_in"}
	self.spawn(function()
		local ok, authenticated = pcall(function()
			return entry.auth:loginWithDeviceCode(function(code)
				entry.state.verification_url = code.verification_url
				entry.state.user_code = code.user_code
				entry.state.expires_at = self.get_time() + entry.auth.device_login_timeout
			end)
		end)
		-- Never render upstream token responses, exception text, or credentials.
		entry.state = ok and authenticated and {status = "authenticated"}
			or {status = "error", error = "OpenAI login failed or expired. Start a new login to retry."}
		if ok and authenticated and self.on_authenticated then
			self.on_authenticated(subscription.id)
		end
	end)
end

return OpenAILoginManager
