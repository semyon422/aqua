local class = require("class")

---@class http.Page
---@operator call: http.Page
local Page = class()

Page.view = nil

---@param domain domain.Domain
---@param user table
---@param params table
function Page:new(domain, user, params)
	self.domain = domain
	self.user = user
	self.params = params
end

function Page:load()
end

return Page
