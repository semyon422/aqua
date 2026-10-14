local RouterDatabase = require("ai.router.storage.RouterDatabase")
local LjsqliteDatabase = require("rdb.db.LjsqliteDatabase")

local test = {}

---@param t testing.T
function test.creates_empty_database(t)
	local storage = RouterDatabase(LjsqliteDatabase())
	storage.path = ":memory:"
	storage:open()
	t:eq(storage.db:user_version(), 3)
	local names = {}
	for _, row in ipairs(storage.db:query("SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name")) do
		table.insert(names, row.name)
	end
	t:tdeq(names, {
		"router_models",
		"router_subscription_windows",
		"router_subscriptions",
		"router_usage_models",
		"router_user_models",
		"router_users",
	})
	storage:close()
end

---@param t testing.T
function test.migrate_is_idempotent(t)
	local storage = RouterDatabase(LjsqliteDatabase())
	storage.path = ":memory:"
	storage:open()
	storage:migrate()
	t:eq(storage.db:user_version(), 3)
	t:eq(#storage.models.router_users:select(), 0)
	storage:close()
end

---@param t testing.T
function test.rejects_future_version(t)
	local storage = RouterDatabase(LjsqliteDatabase())
	storage.path = ":memory:"
	storage:open()
	storage.db:user_version(4)
	t:has_error(function() storage:migrate() end)
	t:eq(storage.db:user_version(), 4)
	storage:close()
end

---@param t testing.T
function test.schema_failure_rolls_back(t)
	local db = LjsqliteDatabase()
	db:open(":memory:")
	db:exec("CREATE TABLE router_users (id INTEGER PRIMARY KEY)")
	local storage = RouterDatabase(db)
	t:has_error(function() storage:migrate() end)
	t:eq(db:user_version(), 0)
	t:eq(#db:query("PRAGMA table_info(router_users)"), 1)
	db:exec("BEGIN")
	db:exec("ROLLBACK")
	db:close()
end

---@param t testing.T
function test.rejects_legacy_schema_without_migrating(t)
	local db = LjsqliteDatabase()
	db:open(":memory:")
	db:exec("CREATE TABLE router_models (id INTEGER PRIMARY KEY, name TEXT, chain TEXT)")
	db:query("INSERT INTO router_models VALUES (1, 'lite', '[\"a\",\"b\"]')")
	db:user_version(1)
	local storage = RouterDatabase(db)
	t:has_error(function() storage:migrate() end)
	t:eq(db:user_version(), 1)
	t:eq(db:query("SELECT chain FROM router_models")[1].chain, '["a","b"]')
	t:tdeq(db:columns("router_models"), {"id", "name", "chain"})
	db:close()
end

---@param t testing.T
function test.rejects_version_two_without_modifying_priority_or_targets(t)
	local db = LjsqliteDatabase()
	db:open(":memory:")
	db:exec("CREATE TABLE router_subscriptions (id INTEGER PRIMARY KEY, priority INTEGER)")
	db:exec("CREATE TABLE router_models (id INTEGER PRIMARY KEY, target TEXT)")
	db:exec("INSERT INTO router_subscriptions VALUES (1, 10)")
	db:exec("INSERT INTO router_models VALUES (1, 'gpt')")
	db:user_version(2)
	local storage = RouterDatabase(db)
	t:has_error(function() storage:migrate() end)
	t:eq(db:user_version(), 2)
	t:eq(db:query("SELECT priority FROM router_subscriptions")[1].priority, 10)
	t:eq(db:query("SELECT target FROM router_models")[1].target, "gpt")
	db:close()
end

return test
