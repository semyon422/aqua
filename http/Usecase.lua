local class = require("class")

---@class http.Usecase
---@operator call: http.Usecase
local Usecase = class()

---@param params table
---@return boolean
function Usecase:authorize(params)
	return false
end

function Usecase:handle(params)
	return "ok", params
end

return Usecase
