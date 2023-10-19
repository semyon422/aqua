local relations = {}

local function preload_relation(objects, rel_name)
	local model = objects[1].__model
	local models = objects[1].__models
	local rel = model.relations[rel_name]
	local rel_objs
	if rel.belongs_to then
		local tbl_name = rel.belongs_to
		local rel_ids = {}
		for i, obj in ipairs(objects) do
			rel_ids[i] = obj[rel.key]
		end
		rel_objs = models[tbl_name]:select({id__in = rel_ids})
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
		local objs_map = {}
		for _, obj in ipairs(objects) do
			objs_map[obj.id] = obj
			obj[tbl_name] = {}
		end
		local ids = {}
		for i, obj in ipairs(objects) do
			ids[i] = obj.id
		end
		rel_objs = models[tbl_name]:select({[rel.key .. "__in"] = ids})
		for _, rel_obj in ipairs(rel_objs) do
			local obj_id = rel_obj[rel.key]
			local obj = objs_map[obj_id]
			table.insert(obj[tbl_name], rel_obj)
		end
	end
	return assert(rel_objs, "no relation objects")
end

local function preload_step(sub_rels, objects, spec, ...)
	local tspec = type(spec)
	if tspec == "table" then
		for rel_name, val in pairs(spec) do
			if type(rel_name) == "number" then
				preload_step(sub_rels, objects, val)
			elseif type(rel_name) == "string" then
				local rel_objs = preload_relation(objects, rel_name)
				sub_rels[val] = sub_rels[val] or {}
				local loaded_objects = sub_rels[val]
				for _, rel_obj in ipairs(rel_objs) do
					table.insert(loaded_objects, rel_obj)
				end
			end
		end
	elseif tspec == "string" then
		preload_relation(objects, spec)
	end
	if select("#", ...) > 0 then
		preload_step(sub_rels, objects, ...)
	end
end

-- lapis-like preload function

---@param objects table
---@param ... any
function relations.preload(objects, ...)
	if #objects == 0 then
		return
	end
	assert(getmetatable(objects[1]), "missing metatable")
	local sub_rels = {}
	preload_step(sub_rels, objects, ...)
	for sub_spec, sub_objects in pairs(sub_rels) do
		relations.preload(sub_objects, sub_spec)
	end
end

return relations
