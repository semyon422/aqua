local relations = {}

---@alias rdb.PreloadSpec string|{[number|string]: rdb.PreloadSpec}
---@alias rdb.Relation {belongs_to: string, has_many: string, key: string}

---@param model rdb.Model
---@param objects rdb.ModelRow[]
---@param rel_name string
---@return rdb.ModelRow[]
---@return rdb.Model
local function preload_relation(model, objects, rel_name)
	local models = model.models
	local rel = model.relations[rel_name]
	---@type rdb.ModelRow[], rdb.Model
	local rel_objs, rel_model
	if rel.belongs_to then
		local tbl_name = rel.belongs_to
		rel_model = models[tbl_name]
		---@type integer[]
		local rel_ids = {}
		for i, obj in ipairs(objects) do
			rel_ids[i] = obj[rel.key]
		end
		rel_objs = rel_model:select({id__in = rel_ids})
		---@type {[integer]: rdb.ModelRow}
		local rel_objs_map = {}
		for _, rel_obj in ipairs(rel_objs) do
			rel_objs_map[rel_obj.id] = rel_obj
		end
		for _, obj in ipairs(objects) do
			local rel_obj_id = obj[rel.key]
			obj[rel_name] = rel_objs_map[rel_obj_id]
		end
	elseif rel.has_many then
		local tbl_name = rel.has_many
		rel_model = models[tbl_name]
		---@type {[integer]: rdb.ModelRow}
		local objs_map = {}
		for _, obj in ipairs(objects) do
			objs_map[obj.id] = obj
			obj[tbl_name] = {}
		end
		---@type integer[]
		local ids = {}
		for i, obj in ipairs(objects) do
			ids[i] = obj.id
		end
		rel_objs = rel_model:select({[rel.key .. "__in"] = ids})
		for _, rel_obj in ipairs(rel_objs) do
			local obj_id = rel_obj[rel.key]
			local obj = objs_map[obj_id]
			table.insert(obj[tbl_name], rel_obj)
		end
	end
	assert(rel_objs, "no relation objects")
	return rel_objs, rel_model
end

---@param model rdb.Model
---@param sub_rels {[rdb.PreloadSpec]: rdb.ModelRow[]}
---@param objects rdb.ModelRow[]
---@param spec rdb.PreloadSpec
---@param ... any
local function preload_step(model, sub_rels, objects, spec, ...)
	local tspec = type(spec)
	if tspec == "table" then
		for rel_name, val in pairs(spec) do
			if type(rel_name) == "number" then
				preload_step(model, sub_rels, objects, val)
			elseif type(rel_name) == "string" then
				local rel_objs, rel_model = preload_relation(model, objects, rel_name)
				assert(not sub_rels[val])
				sub_rels[val] = {model = rel_model}
				local loaded_objects = sub_rels[val]
				for _, rel_obj in ipairs(rel_objs) do
					table.insert(loaded_objects, rel_obj)
				end
			end
		end
	elseif tspec == "string" then
		preload_relation(model, objects, spec)
	end
	if select("#", ...) > 0 then
		preload_step(model, sub_rels, objects, ...)
	end
end

-- lapis-like preload function

---@param model rdb.Model
---@param objects rdb.ModelRow[]
---@param ... any
function relations.preload(model, objects, ...)
	if #objects == 0 then
		return
	end
	---@type {[rdb.PreloadSpec]: rdb.ModelRow[]}
	local sub_rels = {}
	preload_step(model, sub_rels, objects, ...)
	for sub_spec, sub_objects in pairs(sub_rels) do
		relations.preload(sub_objects.model, sub_objects, sub_spec)
	end
end

return relations
