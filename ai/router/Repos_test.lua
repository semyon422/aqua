local UsersRepo = require("ai.router.UsersRepo")
local SubscriptionsRepo = require("ai.router.SubscriptionsRepo")
local ModelsRepo = require("ai.router.ModelsRepo")
local WindowsRepo = require("ai.router.WindowsRepo")
local RouterDatabase = require("ai.router.storage.RouterDatabase")
local LjsqliteDatabase = require("rdb.db.LjsqliteDatabase")
local digest = require("digest")

local test = {}

---@return ai.router.UsersRepo
---@return ai.router.SubscriptionsRepo
---@return ai.router.ModelsRepo
---@return ai.router.WindowsRepo
---@return ai.router.RouterDatabase
local function open()
	local storage = RouterDatabase(LjsqliteDatabase())
	storage.path = ":memory:"
	storage:open()
	return UsersRepo(storage.models), SubscriptionsRepo(storage.models),
		ModelsRepo(storage.models), WindowsRepo(storage.models), storage
end

---@param t testing.T
function test.users_lifecycle(t)
	local users, _, _, _, storage = open()
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
function test.subscriptions_lifecycle(t)
	local _, subs, _, _, storage = open()
	local sub = subs:create("zai-1", "zai", 10,
		{base_url = "https://api.z.ai/api/coding/paas/v4", models = {"glm-5.3"}},
		{five_hour_threshold = 80}, 1000)
	t:eq(sub.enabled, true)
	t:eq(sub.config.models[1], "glm-5.3")
	t:eq(sub.limits.five_hour_threshold, 80)

	t:eq(subs:findByName("zai-1").id, sub.id)
	t:eq(#subs:list(), 1)

	local updated = subs:update(sub.id, {enabled = false, priority = 5}, 1001)
	t:eq(updated.enabled, false)
	t:eq(updated.priority, 5)
	t:eq(subs:get(sub.id).limits.five_hour_threshold, 80)

	t:has_error(function() subs:create("bad", "anthropic", 1, {}, {}, 1002) end)
	t:has_error(function() subs:create("bad", "zai", 1.5, {}, {}, 1002) end)
	t:has_error(function() subs:create("bad", "zai", 1, {1, 2}, {}, 1002) end)

	subs:delete(sub.id)
	t:eq(subs:get(sub.id), nil)
	storage:close()
end

---@param t testing.T
function test.models_lifecycle(t)
	local _, _, models, _, storage = open()
	local model = models:create("lite", {"glm-5.3-flash", "gpt-6-luna"}, "cheap chain", 1000)
	t:eq(model.name, "lite")
	t:eq(model.chain[1], "glm-5.3-flash")
	t:eq(model.chain[2], "gpt-6-luna")
	t:eq(model.description, "cheap chain")

	t:eq(models:findByName("lite").id, model.id)

	local updated = models:update(model.id, {chain = {"glm-5.3"}}, 1001)
	t:tdeq(updated.chain, {"glm-5.3"})
	t:eq(updated.description, "cheap chain")

	t:has_error(function() models:create("loop", {"loop"}, nil, 1002) end)
	t:has_error(function() models:create("dup", {"a", "a"}, nil, 1002) end)
	t:has_error(function() models:create("empty", {}, nil, 1002) end)
	t:has_error(function() models:update(model.id, {chain = {}}, 1002) end)

	models:delete(model.id)
	t:eq(models:findByName("lite"), nil)
	storage:close()
end

---@param t testing.T
function test.windows_snapshots(t)
	local _, subs, _, windows, storage = open()
	local sub = subs:create("zai-1", "zai", 1, {models = {}}, {}, 1000)

	windows:save(sub.id, "five_hour",
		{used_percent = 42.5, used_tokens = 850, quota_tokens = 2000, reset_at = 2000, source = "upstream"}, 1500)
	local snapshot = windows:snapshot(sub.id)
	t:eq(snapshot.five_hour.used_percent, 42.5)
	t:eq(snapshot.five_hour.source, "upstream")

	windows:save(sub.id, "five_hour", {used_percent = 60, source = "local"}, 1600)
	windows:save(sub.id, "weekly", {used_percent = 10, source = "local"}, 1600)
	snapshot = windows:snapshot(sub.id)
	t:eq(snapshot.five_hour.used_percent, 60)
	t:eq(snapshot.five_hour.used_tokens, nil)
	t:eq(snapshot.weekly.used_percent, 10)
	t:eq(#subs:list(), 1)

	windows:delete(sub.id)
	t:eq(next(windows:snapshot(sub.id)), nil)
	subs:delete(sub.id)
	t:eq(next(windows:snapshot(sub.id)), nil)
	t:has_error(function() windows:save(sub.id, "monthly", {source = "local"}, 1700) end)
	storage:close()
end

return test
