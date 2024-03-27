local class = require("class")
local Usecase = require("http.Usecase")

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
	local mod = t._usecases[k]
	mod.config = t._config
	mod.domain = t._domain
	t[k] = Usecase(mod)
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
