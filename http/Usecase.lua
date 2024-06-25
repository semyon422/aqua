local class = require("class")

---@class http.Usecase
---@operator call: http.Usecase
local Usecase = class()

---@param domain domain.Domain
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
