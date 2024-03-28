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

---@param params table
---@return boolean
function Usecase:authorize(params)
	return false
end

function Usecase:handle(params)
	return "ok", params
end

return Usecase
