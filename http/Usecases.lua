local class = require("class")
local Usecase = require("http.Usecase")

---@class http.Usecases
---@operator call: http.Usecases
---@field _usecases table
---@field _validator table
---@field _models table
---@field _access table
---@field _before function?
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
	mod._validator = t._validator
	mod._models = t._models
	mod._access = t._access
	mod._before = t._before
	t[k] = Usecase(mod)
	return t[k]
end

---@param usecases table
---@param validator table
---@param models table
---@param access table
---@param before function
function Usecases:new(usecases, validator, models, access, before)
	self._usecases = usecases
	self._validator = validator
	self._models = models
	self._access = access
	self._before = before
end

return Usecases
