local class = require("class")
local Model = require("rdb.Model")

---@class rdb.Models
---@operator call: rdb.Models
---@field _models table
---@field _orm rdb.TableOrm
---@field [string] rdb.Model
local Models = class()

---@param k string
---@return any?
function Models:__index(k)
	---@type rdb.ModelOptions
	local mod = assert(self._models[k])
	self[k] = Model(mod, self)
	return self[k]
end

---@param orm rdb.TableOrm
---@param models table
function Models:new(models, orm)
	self._models = models
	self._orm = orm
end

return Models
