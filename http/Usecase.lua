local class = require("class")

---@class http.Usecase
---@operator call: http.Usecase
local Usecase = class()

---@param domain domain.Domain
---@param config table
function Usecase:new(domain, config)
	self.domain = domain
	self.config = config
end

function Usecase:handle(params)
	return "ok", params
end

return Usecase
