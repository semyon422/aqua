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
function Models:new(models, orm)
	self._models = models
	self._orm = orm
end

---@param obj_name string
---@param bind_config table
---@param ctx table
---@return boolean?
function Models:select_binded(obj_name, bind_config, ctx)
	local name, keys, rels = unpack(bind_config)
	local where = {}
	for k, v in pairs(keys) do
		if type(k) ~= "string" then
			k = v
		elseif type(v) == "table" then
			local _v = ctx
			for _, _k in ipairs(v) do
				_v = _v[_k]
				if _v == nil then
					return
				end
			end
			_v = v
		else
			return
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

	return true
end

---@param ctx table
---@param model_params table
---@return boolean?
function Models:select(ctx, model_params)
	if not model_params then
		return true
	end

	for obj_name, bind_config in pairs(model_params) do
		if type(obj_name) == "string" then
			local found = self:select_binded(obj_name, bind_config, ctx)
			if not found then
				return
			end
		end
	end
	if model_params[1] then
		model_params[1](ctx)
	end

	return true
end

return Models
