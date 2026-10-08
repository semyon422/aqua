local class = require("class")
local digest = require("digest")
local random = require("web.random")

---@class ai.router.UserRow
---@field id integer
---@field name string
---@field key_hash string
---@field key_hint string
---@field disabled boolean
---@field max_concurrency integer?
---@field max_rpm integer?
---@field created_at integer
---@field updated_at integer

-- Named proxy users with hashed API keys and public-model grants.
---@class ai.router.UsersRepo
---@operator call: ai.router.UsersRepo
---@field models rdb.Models
local UsersRepo = class()

UsersRepo.key_length = 48

---@param name string
local function assertName(name)
	assert(type(name) == "string" and #name >= 1 and #name <= 64, "user name must be 1-64 characters")
end

---@param value number
---@param key string
local function assertPositiveInteger(value, key)
	assert(type(value) == "number" and value % 1 == 0 and value >= 1, key .. " must be a positive integer")
end

---@param model string
local function assertModelName(model)
	assert(type(model) == "string" and #model >= 1 and #model <= 128, "granted model must be a 1-128 character name")
end

-- Generates a fresh bearer key. The plain key is shown once at creation;
-- only its SHA-256 hash and a short hint are persisted.
---@return string key
---@return string key_hash
---@return string key_hint
function UsersRepo.generateKey()
	local key = random.hex(UsersRepo.key_length)
	return key, digest.hash("sha256", key, true), key:sub(-4)
end

---@param models rdb.Models
function UsersRepo:new(models)
	self.models = models
end

---@param name string
---@param now integer
---@return ai.router.UserRow user
---@return string key
function UsersRepo:create(name, now)
	assertName(name)
	local key, key_hash, key_hint = UsersRepo.generateKey()
	local user = self.models.router_users:create({
		name = name,
		key_hash = key_hash,
		key_hint = key_hint,
		disabled = false,
		created_at = now,
		updated_at = now,
	})
	return user, key
end

---@param id integer
---@param now integer
---@return string key
function UsersRepo:regenerateKey(id, now)
	local key, key_hash, key_hint = UsersRepo.generateKey()
	local rows = self.models.router_users:update(
		{key_hash = key_hash, key_hint = key_hint, updated_at = now},
		{id = id}
	)
	assert(#rows == 1, "user not found: " .. id)
	return key
end

---@param id integer
---@return ai.router.UserRow?
function UsersRepo:get(id)
	return self.models.router_users:find({id = id})
end

---@param name string
---@return ai.router.UserRow?
function UsersRepo:findByName(name)
	return self.models.router_users:find({name = name})
end

---@param key_hash string
---@return ai.router.UserRow?
function UsersRepo:findByKeyHash(key_hash)
	return self.models.router_users:find({key_hash = key_hash})
end

---@return ai.router.UserRow[]
function UsersRepo:list()
	return self.models.router_users:select(nil, {order = {"id"}})
end

---@class ai.router.UserChanges
---@field name string?
---@field disabled boolean?
---@field max_concurrency integer?
---@field max_rpm integer?

---@param id integer
---@param changes ai.router.UserChanges
---@param now integer
---@return ai.router.UserRow
function UsersRepo:update(id, changes, now)
	if changes.name ~= nil then assertName(changes.name) end
	assert(changes.disabled == nil or type(changes.disabled) == "boolean", "disabled must be a boolean")
	if changes.max_concurrency ~= nil then
		assertPositiveInteger(changes.max_concurrency, "max_concurrency")
	end
	if changes.max_rpm ~= nil then
		assertPositiveInteger(changes.max_rpm, "max_rpm")
	end
	local row = {updated_at = now}
	if changes.name ~= nil then row.name = changes.name end
	if changes.disabled ~= nil then row.disabled = changes.disabled end
	if changes.max_concurrency ~= nil then row.max_concurrency = changes.max_concurrency end
	if changes.max_rpm ~= nil then row.max_rpm = changes.max_rpm end
	local rows = self.models.router_users:update(row, {id = id})
	assert(#rows == 1, "user not found: " .. id)
	return rows[1]
end

---@param id integer
function UsersRepo:delete(id)
	self.models.router_user_models:delete({user_id = id})
	local rows = self.models.router_users:delete({id = id})
	assert(#rows == 1, "user not found: " .. id)
end

---@class ai.router.UserModelRow
---@field user_id integer
---@field model string

---@param id integer
---@return string[]
function UsersRepo:getGrants(id)
	local rows = self.models.router_user_models:select({user_id = id}, {order = {"model"}})
	---@cast rows ai.router.UserModelRow[]
	---@type string[]
	local models = {}
	for i, row in ipairs(rows) do
		models[i] = row.model
	end
	return models
end

-- Replaces the user's granted public models with the given list.
---@param id integer
---@param models string[]
function UsersRepo:setGrants(id, models)
	assert(type(models) == "table", "grants must be a list of model names")
	---@type {[string]: boolean}
	local seen = {}
	for _, model in ipairs(models) do
		assertModelName(model)
		assert(not seen[model], "duplicate granted model: " .. model)
		seen[model] = true
	end
	self.models.router_user_models:delete({user_id = id})
	---@type ai.router.UserModelRow[]
	local rows = {}
	for i, model in ipairs(models) do
		rows[i] = {user_id = id, model = model}
	end
	if #rows > 0 then
		self.models.router_user_models:insert(rows)
	end
end

return UsersRepo
