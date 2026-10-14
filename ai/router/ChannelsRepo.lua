local class = require("class")

---@class ai.router.ChannelRow
---@field id integer
---@field name string
---@field kind "openai"|"zai"|"openai_compat"
---@field enabled boolean
---@field config table
---@field limits table
---@field created_at integer
---@field updated_at integer

-- Inference channels: subscription accounts or compatible proxies. Config and limits are JSON
-- objects; deep validation lives in ai.router.Catalog so management saves and
-- runtime state share one validator.
---@class ai.router.ChannelsRepo
---@operator call: ai.router.ChannelsRepo
---@field models rdb.Models
local ChannelsRepo = class()

ChannelsRepo.kinds = {
	openai = true,
	zai = true,
	openai_compat = true,
}

---@param name string
local function assertName(name)
	assert(type(name) == "string" and #name >= 1 and #name <= 64, "channel name must be 1-64 characters")
	assert(name:match("^[%w._%-]+$"), "channel name must contain only letters, digits, ._-")
end

---@param kind any
local function assertKind(kind)
	assert(type(kind) == "string" and ChannelsRepo.kinds[kind], "unknown channel kind: " .. tostring(kind))
end

---@param value any
---@param label string
local function assertObject(value, label)
	assert(type(value) == "table" and #value == 0, label .. " must be an object")
end

---@param models rdb.Models
function ChannelsRepo:new(models)
	self.models = models
end

---@param name string
---@param kind "openai"|"zai"|"openai_compat"
---@param config table
---@param limits table
---@param now integer
---@return ai.router.ChannelRow
function ChannelsRepo:create(name, kind, config, limits, now)
	assertName(name)
	assertKind(kind)
	assertObject(config, "config")
	assertObject(limits, "limits")
	return self.models.router_channels:create({
		name = name,
		kind = kind,
		enabled = true,
		config = config,
		limits = limits,
		created_at = now,
		updated_at = now,
	})
end

---@param id integer
---@return ai.router.ChannelRow?
function ChannelsRepo:get(id)
	return self.models.router_channels:find({id = id})
end

---@param name string
---@return ai.router.ChannelRow?
function ChannelsRepo:findByName(name)
	return self.models.router_channels:find({name = name})
end

---@return ai.router.ChannelRow[]
function ChannelsRepo:list()
	return self.models.router_channels:select(nil, {order = {"id"}})
end

---@class ai.router.ChannelChanges
---@field name string?
---@field kind "openai"|"zai"|"openai_compat"?
---@field enabled boolean?
---@field config table?
---@field limits table?

---@param id integer
---@param changes ai.router.ChannelChanges
---@param now integer
---@return ai.router.ChannelRow
function ChannelsRepo:update(id, changes, now)
	if changes.name ~= nil then assertName(changes.name) end
	if changes.kind ~= nil then assertKind(changes.kind) end
	if changes.config ~= nil then assertObject(changes.config, "config") end
	if changes.limits ~= nil then assertObject(changes.limits, "limits") end
	assert(changes.enabled == nil or type(changes.enabled) == "boolean", "enabled must be a boolean")
	local row = {updated_at = now}
	for _, key in ipairs({"name", "kind", "enabled", "config", "limits"}) do
		if changes[key] ~= nil then row[key] = changes[key] end
	end
	local rows = self.models.router_channels:update(row, {id = id})
	assert(#rows == 1, "channel not found: " .. id)
	return rows[1]
end

---@param id integer
function ChannelsRepo:delete(id)
	local rows = self.models.router_channels:delete({id = id})
	assert(#rows == 1, "channel not found: " .. id)
end

return ChannelsRepo
