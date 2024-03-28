local class = require("class")

---@class http.Usecases
---@operator call: http.Usecases
---@field _usecases table
---@field _config table
---@field _domain table
---@field [string] http.Usecase
local Usecases = class()

---@param t table
---@param k string
---@return any?
function Usecases.__index(t, k)
	if k:sub(1, 1) == "_" then
		return
	end
	local Uc = t._usecases[k]
	t[k] = Uc(t._domain, t._config)
	return t[k]
end

---@param usecases table
---@param config table
---@param domain table
function Usecases:new(usecases, config, domain)
	self._usecases = usecases
	self._config = config
	self._domain = domain
end

return Usecases
