local class = require("class")
local json = require("web.json")

---@class ai.router.ModelRow
---@field id integer
---@field name string
---@field chain string[] ordered target public model names
---@field description string?
---@field created_at integer
---@field updated_at integer

-- Custom alias models with ordered fallback chains. Chain entries must be
-- concrete catalog models (served by some subscription); that cross-table
-- check lives in ai.router.Catalog.
---@class ai.router.ModelsRepo
---@operator call: ai.router.ModelsRepo
---@field models rdb.Models
local ModelsRepo = class()

ModelsRepo.max_chain_length = 16

---@param name string
local function assertName(name)
	assert(type(name) == "string" and #name >= 1 and #name <= 128, "model name must be 1-128 characters")
end

---@param name string
---@param chain any
local function assertChain(name, chain)
	assert(type(chain) == "table" and #chain >= 1 and #chain <= ModelsRepo.max_chain_length,
		("chain must be a list of 1-%d model names"):format(ModelsRepo.max_chain_length))
	---@cast chain string[]
	---@type {[string]: boolean}
	local seen = {}
	for i, entry in ipairs(chain) do
		assert(type(entry) == "string" and #entry >= 1 and #entry <= 128,
			("chain entry %d must be a 1-128 character name"):format(i))
		assert(entry ~= name, "chain entry must not reference the alias itself")
		assert(not seen[entry], "duplicate chain entry: " .. entry)
		seen[entry] = true
	end
end

---@param models rdb.Models
function ModelsRepo:new(models)
	self.models = models
end

---@param name string
---@param chain string[]
---@param description string?
---@param now integer
---@return ai.router.ModelRow
function ModelsRepo:create(name, chain, description, now)
	assertName(name)
	assertChain(name, chain)
	assert(description == nil or (type(description) == "string" and #description <= 256),
		"description must be at most 256 characters")
	return self.models.router_models:create({
		name = name,
		chain = json.array(chain),
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
---@field chain string[]?
---@field description string?

---@param id integer
---@param changes ai.router.ModelChanges
---@param now integer
---@return ai.router.ModelRow
function ModelsRepo:update(id, changes, now)
	local current = self.models.router_models:find({id = id})
	assert(current, "model not found: " .. id)
	local name = changes.name or current.name
	local chain = changes.chain or current.chain
	if changes.name ~= nil then assertName(changes.name) end
	if changes.chain ~= nil then assertChain(name, chain) end
	if changes.description ~= nil then
		assert(type(changes.description) == "string" and #changes.description <= 256,
			"description must be at most 256 characters")
	end
	local row = {updated_at = now}
	if changes.name ~= nil then row.name = changes.name end
	if changes.chain ~= nil then row.chain = json.array(chain) end
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
