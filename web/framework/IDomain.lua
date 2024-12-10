local class = require("class")

---@class web.IDomain
---@operator call: web.IDomain
local IDomain = class()

---@param id integer
---@return table
function IDomain:getUser(id)
	return {}
end

return IDomain
