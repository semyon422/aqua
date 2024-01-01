local class = require("class")
local Model = require("rdb.Model")
local relations = require("rdb.relations")

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
	local v = Models[k]
	if v then
		return v
	end
	local mod = assert(t._models[k])
	t[k] = Model(mod, t)
	return t[k]
end

---@param orm rdb.TableOrm
---@param models table
function Models:new(orm, models)
	self._orm = orm
	self._models = models
end

---@param ctx table
---@param model_params table
---@return boolean?
function Models:select(ctx, model_params)
	if not model_params then
		return true
	end

	for _, t in ipairs(model_params) do
		local obj_name, bind_config = next(t)
		local name, keys, rels = unpack(bind_config)
		local where = {}
		for k, v in pairs(keys) do
			if type(k) ~= "string" then
				k = v
			end
			where[k] = tonumber(ctx[v]) or ctx[v]
		end

		local objs = self[name]:select(where)
		if #objs == 0 then
			return
		end
		if rels then
			relations.preload(objs, rels)
		end

		ctx[obj_name] = objs[1]
	end

	if model_params.after then
		model_params.after(ctx)
	end

	return true
end

return Models
