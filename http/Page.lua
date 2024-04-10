local class = require("class")

---@class http.Page
---@operator call: http.Page
local Page = class()

Page.view = nil

---@param domain domain.Domain
---@param params table
---@param user table
---@param config table
function Page:new(domain, params, user, config)
	self.domain = domain
	self.params = params
	self.user = user
	self.config = config
end

function Page:load()
end

return Page
