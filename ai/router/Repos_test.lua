local UsersRepo = require("ai.router.UsersRepo")
local ChannelsRepo = require("ai.router.ChannelsRepo")
local ModelsRepo = require("ai.router.ModelsRepo")
local RouterDatabase = require("ai.router.storage.RouterDatabase")
local LjsqliteDatabase = require("rdb.db.LjsqliteDatabase")
local digest = require("digest")

local test = {}

---@return ai.router.UsersRepo
---@return ai.router.ChannelsRepo
---@return ai.router.ModelsRepo
---@return ai.router.RouterDatabase
local function open()
	local storage = RouterDatabase(LjsqliteDatabase())
	storage.path = ":memory:"
	storage:open()
	return UsersRepo(storage.models), ChannelsRepo(storage.models),
		ModelsRepo(storage.models), storage
end

---@param t testing.T
function test.users_lifecycle(t)
	local users, _, _, storage = open()
	local user, key = users:create("alice", 1000)
	t:eq(user.name, "alice")
	t:eq(user.disabled, false)
	t:eq(#key, UsersRepo.key_length)
	t:eq(digest.hash("sha256", key, true), user.key_hash)
	t:eq(user.key_hint, key:sub(-4))

	t:eq(users:findByKeyHash(user.key_hash).id, user.id)
	t:eq(users:findByName("alice").id, user.id)
	t:eq(users:findByName("bob"), nil)

	users:setGrants(user.id, {"lite", "glm-5.3"})
	t:tdeq(users:getGrants(user.id), {"glm-5.3", "lite"})
	users:setGrants(user.id, {"lite"})
	t:tdeq(users:getGrants(user.id), {"lite"})

	t:has_error(function() users:setGrants(user.id, {"lite", "lite"}) end)
	t:has_error(function() users:setGrants(user.id, {""}) end)

	local updated = users:update(user.id, {disabled = true, max_rpm = 10}, 1001)
	t:eq(updated.disabled, true)
	t:eq(updated.max_rpm, 10)
	t:eq(updated.updated_at, 1001)
	t:has_error(function() users:update(user.id, {max_rpm = 0}, 1002) end)

	local new_key = users:regenerateKey(user.id, 1002)
	t:eq(users:findByKeyHash(digest.hash("sha256", new_key, true)).id, user.id)
	t:eq(users:findByKeyHash(user.key_hash), nil)

	users:delete(user.id)
	t:eq(users:get(user.id), nil)
	t:tdeq(users:getGrants(user.id), {})
	storage:close()
end

---@param t testing.T
function test.channels_lifecycle(t)
	local _, subs, _, storage = open()
	local sub = subs:create("zai-1", "zai",
		{base_url = "https://api.z.ai/api/coding/paas/v4", models = {"glm-5.3"}},
		{poll_interval = 80}, 1000)
	t:eq(sub.enabled, true)
	t:eq(sub.config.models[1], "glm-5.3")
	t:eq(sub.limits.poll_interval, 80)

	t:eq(subs:findByName("zai-1").id, sub.id)
	t:eq(#subs:list(), 1)

	local updated = subs:update(sub.id, {enabled = false, name = "zai-main"}, 1001)
	t:eq(updated.enabled, false)
	t:eq(updated.name, "zai-main")
	t:eq(subs:get(sub.id).limits.poll_interval, 80)

	t:has_error(function() subs:create("bad", "anthropic", {}, {}, 1002) end)
	t:has_error(function() subs:create("bad/name", "zai", {}, {}, 1002) end)
	t:has_error(function() subs:create("bad", "zai", {1, 2}, {}, 1002) end)

	subs:delete(sub.id)
	t:eq(subs:get(sub.id), nil)
	storage:close()
end

---@param t testing.T
function test.models_lifecycle(t)
	local _, _, models, storage = open()
	local model = models:create("lite", "zai/glm-5.3-flash", "cheap alias", 1000)
	t:eq(model.name, "lite")
	t:eq(model.target, "zai/glm-5.3-flash")
	t:eq(model.description, "cheap alias")

	t:eq(models:findByName("lite").id, model.id)

	local updated = models:update(model.id, {target = "zai/glm-5.3"}, 1001)
	t:eq(updated.target, "zai/glm-5.3")
	t:eq(updated.description, "cheap alias")

	t:has_error(function() models:create("loop", "loop", nil, 1002) end)
	t:has_error(function() models:create("bad", {"a", "b"}, nil, 1002) end)
	t:has_error(function() models:create("empty", "", nil, 1002) end)
	t:has_error(function() models:update(model.id, {target = ""}, 1002) end)
	t:has_error(function() models:update(model.id, {name = "zai/glm-5.3"}, 1002) end)

	models:delete(model.id)
	t:eq(models:findByName("lite"), nil)
	storage:close()
end

---@param t testing.T
function test.channel_lifecycle_requires_no_persisted_quota_table(t)
	local _, channels, _, storage = open()
	local channel = channels:create("zai-1", "zai", {models = {}}, {}, 1000)
	t:eq(#channels:list(), 1)
	channels:delete(channel.id)
	t:eq(#channels:list(), 0)
	t:eq(#storage.db:query("SELECT name FROM sqlite_master WHERE name = 'router_channel_windows'"), 0)
	storage:close()
end

return test
