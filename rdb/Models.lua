local class = require("class")
local Model = require("rdb.Model")

---@class rdb.Models
---@operator call: rdb.Models
---@field _prefix string
---@field _orm rdb.TableOrm
---@field [string] rdb.Model
local Models = class()

---@param t table
---@param mod_name string
---@return any?
function Models.__index(t, mod_name)
	local mod = require(t._prefix .. "." .. mod_name)
	t[mod_name] = Model(mod, t)
	return t[mod_name]
end

---@param prefix string
---@param orm rdb.TableOrm
function Models:new(prefix, orm)
	self._prefix = prefix
	self._orm = orm
end

return Models
