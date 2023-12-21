local class = require("class")
local Model = require("rdb.Model")

---@class rdb.Models
---@operator call: rdb.Models
---@field _models table
---@field _orm rdb.TableOrm
---@field [string] rdb.Model
local Models = class()

---@param t table
---@param k string
---@return any?
function Models.__index(t, k)
	local mod = t._models[k]
	t[k] = Model(mod, t)
	return t[k]
end

---@param orm rdb.TableOrm
---@param models table
function Models:new(orm, models)
	self._orm = orm
	self._models = models
end

return Models
