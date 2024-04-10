local class = require("class")

---@class http.Page
---@operator call: http.Page
local Page = class()

Page.view = nil

---@param domain domain.Domain
---@param params table
---@param user table
function Page:new(domain, params, user)
	self.domain = domain
	self.params = params
	self.user = user
end

function Page:load()
end

return Page
