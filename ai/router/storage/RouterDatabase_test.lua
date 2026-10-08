local RouterDatabase = require("ai.router.storage.RouterDatabase")
local LjsqliteDatabase = require("rdb.db.LjsqliteDatabase")

local test = {}

---@param t testing.T
function test.creates_empty_database(t)
	local storage = RouterDatabase(LjsqliteDatabase())
	storage.path = ":memory:"
	storage:open()
	t:eq(storage.db:user_version(), 1)
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
	t:eq(storage.db:user_version(), 1)
	t:eq(#storage.models.router_users:select(), 0)
	storage:close()
end

---@param t testing.T
function test.rejects_future_version(t)
	local storage = RouterDatabase(LjsqliteDatabase())
	storage.path = ":memory:"
	storage:open()
	storage.db:user_version(2)
	t:has_error(function() storage:migrate() end)
	t:eq(storage.db:user_version(), 2)
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

return test
