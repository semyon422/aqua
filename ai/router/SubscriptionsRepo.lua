local class = require("class")

---@class ai.router.SubscriptionRow
---@field id integer
---@field name string
---@field kind "openai"|"zai"|"openai_compat"
---@field priority integer
---@field enabled boolean
---@field config table
---@field limits table
---@field created_at integer
---@field updated_at integer

-- Upstream subscriptions. `config` and `limits` are kind-specific JSON
-- objects; deep validation lives in ai.router.Catalog so admin saves and
-- runtime state share one validator.
---@class ai.router.SubscriptionsRepo
---@operator call: ai.router.SubscriptionsRepo
---@field models rdb.Models
local SubscriptionsRepo = class()

SubscriptionsRepo.kinds = {
	openai = true,
	zai = true,
	openai_compat = true,
}

---@param name string
local function assertName(name)
	assert(type(name) == "string" and #name >= 1 and #name <= 64, "subscription name must be 1-64 characters")
end

---@param kind any
local function assertKind(kind)
	assert(type(kind) == "string" and SubscriptionsRepo.kinds[kind], "unknown subscription kind: " .. tostring(kind))
end

---@param value any
---@param label string
local function assertObject(value, label)
	assert(type(value) == "table" and #value == 0, label .. " must be an object")
end

---@param priority any
local function assertPriority(priority)
	assert(type(priority) == "number" and priority % 1 == 0, "priority must be an integer")
end

---@param models rdb.Models
function SubscriptionsRepo:new(models)
	self.models = models
end

---@param name string
---@param kind "openai"|"zai"|"openai_compat"
---@param priority integer
---@param config table
---@param limits table
---@param now integer
---@return ai.router.SubscriptionRow
function SubscriptionsRepo:create(name, kind, priority, config, limits, now)
	assertName(name)
	assertKind(kind)
	assertPriority(priority)
	assertObject(config, "config")
	assertObject(limits, "limits")
	return self.models.router_subscriptions:create({
		name = name,
		kind = kind,
		priority = priority,
		enabled = true,
		config = config,
		limits = limits,
		created_at = now,
		updated_at = now,
	})
end

---@param id integer
---@return ai.router.SubscriptionRow?
function SubscriptionsRepo:get(id)
	return self.models.router_subscriptions:find({id = id})
end

---@param name string
---@return ai.router.SubscriptionRow?
function SubscriptionsRepo:findByName(name)
	return self.models.router_subscriptions:find({name = name})
end

---@return ai.router.SubscriptionRow[]
function SubscriptionsRepo:list()
	return self.models.router_subscriptions:select(nil, {order = {"priority", "id"}})
end

---@class ai.router.SubscriptionChanges
---@field name string?
---@field kind "openai"|"zai"|"openai_compat"?
---@field priority integer?
---@field enabled boolean?
---@field config table?
---@field limits table?

---@param id integer
---@param changes ai.router.SubscriptionChanges
---@param now integer
---@return ai.router.SubscriptionRow
function SubscriptionsRepo:update(id, changes, now)
	if changes.name ~= nil then assertName(changes.name) end
	if changes.kind ~= nil then assertKind(changes.kind) end
	if changes.priority ~= nil then assertPriority(changes.priority) end
	if changes.config ~= nil then assertObject(changes.config, "config") end
	if changes.limits ~= nil then assertObject(changes.limits, "limits") end
	assert(changes.enabled == nil or type(changes.enabled) == "boolean", "enabled must be a boolean")
	local row = {updated_at = now}
	for _, key in ipairs({"name", "kind", "priority", "enabled", "config", "limits"}) do
		if changes[key] ~= nil then row[key] = changes[key] end
	end
	local rows = self.models.router_subscriptions:update(row, {id = id})
	assert(#rows == 1, "subscription not found: " .. id)
	return rows[1]
end

---@param id integer
function SubscriptionsRepo:delete(id)
	self.models.router_subscription_windows:delete({subscription_id = id})
	local rows = self.models.router_subscriptions:delete({id = id})
	assert(#rows == 1, "subscription not found: " .. id)
end

return SubscriptionsRepo
