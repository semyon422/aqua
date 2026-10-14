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
---@field generation string

---@class ai.router.OpenAILoginManagerOptions
---@field scheduler web.CosocketScheduler
---@field create_auth fun(channel_id: integer): openai.SubscriptionAuth
---@field oauth_repo ai.router.OAuthRepo
---@field on_authenticated (fun(channel_id: integer))?
---@field spawn (fun(callback: fun()))?
---@field get_time (fun(): number)?

---@class ai.router.OpenAILoginManager
---@operator call: ai.router.OpenAILoginManager
---@field entries {[integer]: ai.router.OpenAILoginEntry}
---@field create_auth fun(channel_id: integer): openai.SubscriptionAuth
---@field oauth_repo ai.router.OAuthRepo
---@field scheduler web.CosocketScheduler
---@field spawn fun(callback: fun())
---@field get_time fun(): number
---@field on_authenticated (fun(channel_id: integer))?
local OpenAILoginManager = class()

---@param options ai.router.OpenAILoginManagerOptions
function OpenAILoginManager:new(options)
	self.entries = {}
	self.scheduler = options.scheduler
	self.create_auth = options.create_auth
	self.oauth_repo = options.oauth_repo
	self.on_authenticated = options.on_authenticated
	self.get_time = options.get_time or os.time
	self.spawn = options.spawn or function(callback)
		local thread = coext.detach(coroutine.create(callback))
		assert(coroutine.resume(thread))
	end
end

---@param channel_id integer
---@return ai.router.OpenAILoginEntry
function OpenAILoginManager:entry(channel_id)
	local generation = self.oauth_repo:get(channel_id).generation
	local entry = self.entries[channel_id]
	if not entry or entry.generation ~= generation then
		local auth = self.create_auth(channel_id)
		entry = {
			auth = auth,
			generation = generation,
			guard = SubscriptionAuthGuard(auth, self.scheduler),
			state = {status = auth:isAuthenticated() and "authenticated" or "unauthenticated"},
		}
		self.entries[channel_id] = entry
	end
	return entry
end

---@param channel_id integer
---@return openai.SubscriptionAuthGuard
function OpenAILoginManager:getGuard(channel_id)
	return self:entry(channel_id).guard
end

---@param channel_id integer
---@return ai.router.OpenAILoginState
function OpenAILoginManager:getState(channel_id)
	return self:entry(channel_id).state
end

---@param channel_id integer
---@return boolean
function OpenAILoginManager:isLoggingIn(channel_id)
	return self:getState(channel_id).status == "logging_in"
end

---@param channel ai.router.ChannelRow
function OpenAILoginManager:start(channel)
	assert(channel.kind == "openai", "device login requires an OpenAI channel")
	local entry = self:entry(channel.id)
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
			self.on_authenticated(channel.id)
		end
	end)
end

return OpenAILoginManager
