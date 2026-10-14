local class = require("class")
local random = require("web.random")

---@class ai.router.OAuthRow: openai.SubscriptionCredentials
---@field channel_id integer
---@field generation string guards against stale refreshes after deletion/kind changes

---@class ai.router.OAuthRepo
---@operator call: ai.router.OAuthRepo
---@field models rdb.Models
local OAuthRepo = class()

---@param models rdb.Models
function OAuthRepo:new(models)
	self.models = models
end

---@param channel_id integer
function OAuthRepo:create(channel_id)
	self.models.router_oauth_credentials:create({channel_id = channel_id, generation = random.hex(16),
		access_token = "", refresh_token = "", expires_at = 0, account_id = ""})
end

---@param channel_id integer
---@return ai.router.OAuthRow
function OAuthRepo:get(channel_id)
	local row = assert(self.models.router_oauth_credentials:find({channel_id = channel_id}), "OAuth credentials not initialized")
	row.expires_at = assert(tonumber(row.expires_at))
	return row
end

---@param channel_id integer
---@param generation string
---@param credentials openai.SubscriptionCredentials
function OAuthRepo:save(channel_id, generation, credentials)
	assert(type(credentials.access_token) == "string" and type(credentials.refresh_token) == "string"
		and type(credentials.account_id) == "string" and type(credentials.expires_at) == "number"
		and credentials.expires_at >= 0 and credentials.expires_at % 1 == 0, "Invalid OAuth credentials")
	local ok, rows = pcall(function()
		return self.models.router_oauth_credentials:update({access_token = credentials.access_token,
			refresh_token = credentials.refresh_token, expires_at = credentials.expires_at, account_id = credentials.account_id},
			{channel_id = channel_id, generation = generation})
	end)
	assert(ok, "OAuth credential write failed")
	assert(#rows == 1, "OAuth credential owner has changed")
end

---@param channel_id integer
function OAuthRepo:delete(channel_id)
	self.models.router_oauth_credentials:delete({channel_id = channel_id})
end

return OAuthRepo
