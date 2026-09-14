local class = require("class")

---@class openai.SubscriptionAuthGuard
---@operator call: openai.SubscriptionAuthGuard
---@field auth openai.ISubscriptionAuth
---@field scheduler web.CosocketScheduler
---@field busy boolean
local SubscriptionAuthGuard = class()

---@param auth openai.ISubscriptionAuth
---@param scheduler web.CosocketScheduler
function SubscriptionAuthGuard:new(auth, scheduler)
	self.auth = auth
	self.scheduler = scheduler
	self.busy = false
end

---@return string?
---@return string?
---@return string?
function SubscriptionAuthGuard:getAccess()
	while self.busy do
		self.scheduler:sleep(0.01)
	end
	self.busy = true

	---@type string?
	local access_token
	---@type string?
	local account_id
	---@type string?
	local access_err
	local ok, call_err = xpcall(function()
		access_token, account_id, access_err = self.auth:getAccess()
	end, debug.traceback)
	self.busy = false

	if not ok then
		error(call_err, 0)
	end
	return access_token, account_id, access_err
end

return SubscriptionAuthGuard
