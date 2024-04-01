local class = require("class")

---@class http.Page
---@operator call: http.Page
local Page = class()

Page.view = nil

---@param domain domain.Domain
---@param params table
function Page:new(domain, params)
	self.domain = domain
	self.params = params
	self.user = params.session_user or self.domain.anonUser
end

function Page:load()
end

return Page
