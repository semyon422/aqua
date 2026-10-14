local class = require("class")

---@class ai.router.ModelRow
---@field id integer
---@field name string
---@field target string concrete public model name
---@field description string?
---@field created_at integer
---@field updated_at integer

-- Simple aliases to concrete catalog models (served by some channel); that cross-table
-- check lives in ai.router.Catalog.
---@class ai.router.ModelsRepo
---@operator call: ai.router.ModelsRepo
---@field models rdb.Models
local ModelsRepo = class()

---@param name string
local function assertName(name)
	assert(type(name) == "string" and #name >= 1 and #name <= 128, "model name must be 1-128 characters")
	assert(not name:find("/", 1, true), "alias name must not contain a slash")
end

---@param name string
---@param target string
local function assertTarget(name, target)
	assert(type(target) == "string" and #target <= 193 and target:match("^[^/]+/.+$"),
		"alias target must be a channel/model name")
	assert(target ~= name, "alias must not reference itself")
end

---@param models rdb.Models
function ModelsRepo:new(models)
	self.models = models
end

---@param name string
---@param target string
---@param description string?
---@param now integer
---@return ai.router.ModelRow
function ModelsRepo:create(name, target, description, now)
	assertName(name)
	assertTarget(name, target)
	assert(description == nil or (type(description) == "string" and #description <= 256),
		"description must be at most 256 characters")
	return self.models.router_models:create({
		name = name,
		target = target,
		description = description,
		created_at = now,
		updated_at = now,
	})
end

---@param id integer
---@return ai.router.ModelRow?
function ModelsRepo:get(id)
	return self.models.router_models:find({id = id})
end

---@param name string
---@return ai.router.ModelRow?
function ModelsRepo:findByName(name)
	return self.models.router_models:find({name = name})
end

---@return ai.router.ModelRow[]
function ModelsRepo:list()
	return self.models.router_models:select(nil, {order = {"name"}})
end

---@class ai.router.ModelChanges
---@field name string?
---@field target string?
---@field description string?

---@param id integer
---@param changes ai.router.ModelChanges
---@param now integer
---@return ai.router.ModelRow
function ModelsRepo:update(id, changes, now)
	local current = self.models.router_models:find({id = id})
	assert(current, "model not found: " .. id)
	local name = changes.name or current.name
	local target = changes.target or current.target
	if changes.name ~= nil then assertName(changes.name) end
	assertTarget(name, target)
	if changes.description ~= nil then
		assert(type(changes.description) == "string" and #changes.description <= 256,
			"description must be at most 256 characters")
	end
	local row = {updated_at = now}
	if changes.name ~= nil then row.name = changes.name end
	if changes.target ~= nil then row.target = target end
	if changes.description ~= nil then row.description = changes.description end
	local rows = self.models.router_models:update(row, {id = id})
	return rows[1]
end

---@param id integer
function ModelsRepo:delete(id)
	local rows = self.models.router_models:delete({id = id})
	assert(#rows == 1, "model not found: " .. id)
end

return ModelsRepo
