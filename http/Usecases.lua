local class = require("class")
local Usecase = require("http.Usecase")

---@class rdb.Usecases
---@operator call: rdb.Usecases
---@field _prefix string
---@field [string] http.Usecase
local Usecases = class()

---@param t table
---@param mod_name string
---@return any?
function Usecases.__index(t, mod_name)
	local mod = require(t._prefix .. "." .. mod_name)

	local usecase = Usecase()
	if mod.policy_set then
		usecase:setPolicySet(mod.policy_set)
	end
	if mod.models then
		usecase:bindModels(mod.models)
	end
	if mod.handler then
		usecase:setHandler(mod.handler)
	end
	if mod.validate then
		usecase:setValidation(mod.validate)
	end

	t[mod_name] = usecase
	return t[mod_name]
end

---@param prefix string
function Usecases:new(prefix)
	self._prefix = prefix
end

return Usecases
