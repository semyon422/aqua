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

local function get_kv(t, k, v)
	if type(k) == "number" then
		k = v
	end

	if type(v) == "string" then  -- {"user_id"} or {id = "user_id"}
		return k, tonumber(t[v]) or t[v]
	elseif type(v) == "table" then  -- {id = {...}}
		local _v = t
		for _, _k in ipairs(v) do
			_v = _v[_k]
			if _v == nil then
				return
			end
		end
		return k, _v
	end
end

---@param obj_name string
---@param bind_config table
---@param ctx table
---@return boolean?
function Models:select_binded(obj_name, bind_config, ctx)
	local name, keys, rels = unpack(bind_config)
	local where = {}
	for k, v in pairs(keys) do
		local key, value = get_kv(ctx, k, v)
		if key == nil or value == nil then
			return
		end
		where[key] = value
	end

	if not next(where) then
		return
	end

	local obj = self[name]:find(where)
	if not obj then
		return
	end
	if rels then
		relations.preload({obj}, rels)
	end

	ctx[obj_name] = obj

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
