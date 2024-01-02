local class = require("class")
local Usecase = require("http.Usecase")

---@class http.Usecases
---@operator call: http.Usecases
---@field _models table
---@field _rules_repo table
---@field [string] http.Usecase
local Usecases = class()

---@param t table
---@param k string
---@return any?
function Usecases.__index(t, k)
	local mod = t._models[k]
	mod._models = t._models
	mod._rules_repo = t._rules_repo
	t[k] = Usecase(mod)
	return t[k]
end

---@param models table
---@param rules_repo table
function Usecases:new(models, rules_repo)
	self._models = models
	self._rules_repo = rules_repo
end

return Usecases
