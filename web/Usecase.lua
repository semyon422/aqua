local class = require("class")

---@class web.Usecase
---@operator call: web.Usecase
local Usecase = class()

---@param domain web.IDomain
---@param config table
---@param user table
function Usecase:new(domain, config, user)
	self.domain = domain
	self.config = config
	self.user = user
end

function Usecase:handle(params)
	return "ok"
end

return Usecase
