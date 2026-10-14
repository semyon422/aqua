local RouterDatabase = require("ai.router.storage.RouterDatabase")
local LjsqliteDatabase = require("rdb.db.LjsqliteDatabase")

local test = {}

---@param t testing.T
function test.creates_empty_database(t)
	local storage = RouterDatabase(LjsqliteDatabase())
	storage.path = ":memory:"
	storage:open()
	t:eq(storage.db:user_version(), 8)
	local names = {}
	for _, row in ipairs(storage.db:query("SELECT name FROM sqlite_master WHERE type = 'table' ORDER BY name")) do
		table.insert(names, row.name)
	end
	t:tdeq(names, {
		"router_channels",
		"router_models",
		"router_oauth_credentials",
		"router_request_logs",
		"router_usage_models",
		"router_user_models",
		"router_users",
		"sqlite_sequence",
	})
	storage:close()
end

---@param t testing.T
function test.migrate_is_idempotent(t)
	local storage = RouterDatabase(LjsqliteDatabase())
	storage.path = ":memory:"
	storage:open()
	storage:migrate()
	t:eq(storage.db:user_version(), 8)
	t:eq(#storage.models.router_users:select(), 0)
	storage:close()
end

---@param t testing.T
function test.rejects_future_version(t)
	local storage = RouterDatabase(LjsqliteDatabase())
	storage.path = ":memory:"
	storage:open()
	storage.db:user_version(9)
	t:has_error(function() storage:migrate() end)
	t:eq(storage.db:user_version(), 9)
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

---@param t testing.T
function test.rejects_subscription_schema_without_renaming_data(t)
	local db = LjsqliteDatabase()
	db:open(":memory:")
	db:exec("CREATE TABLE router_subscriptions (id INTEGER PRIMARY KEY, name TEXT)")
	db:exec("CREATE TABLE router_usage_models (subscription TEXT)")
	db:exec("INSERT INTO router_subscriptions VALUES (1, 'openai')")
	db:exec("INSERT INTO router_usage_models VALUES ('openai')")
	db:user_version(3)
	local storage = RouterDatabase(db)
	t:has_error(function() storage:migrate() end)
	t:eq(db:user_version(), 3)
	t:eq(db:query("SELECT name FROM router_subscriptions")[1].name, "openai")
	t:eq(db:query("SELECT subscription FROM router_usage_models")[1].subscription, "openai")
	db:close()
end

---@param t testing.T
function test.rejects_version_four_without_adding_request_logs(t)
	local db = LjsqliteDatabase()
	db:open(":memory:")
	db:exec("CREATE TABLE router_channels (id INTEGER PRIMARY KEY, name TEXT)")
	db:exec("INSERT INTO router_channels VALUES (3, 'zai')")
	db:user_version(4)
	local storage = RouterDatabase(db)
	t:has_error(function() storage:migrate() end)
	t:eq(db:user_version(), 4)
	t:eq(db:query("SELECT name FROM router_channels")[1].name, "zai")
	t:eq(#db:query("SELECT name FROM sqlite_master WHERE name = 'router_request_logs'"), 0)
	db:close()
end

---@param t testing.T
function test.rejects_version_five_without_rewriting_request_history(t)
	local db = LjsqliteDatabase()
	db:open(":memory:")
	db:exec("CREATE TABLE router_request_logs (id INTEGER PRIMARY KEY, model TEXT)")
	db:exec("INSERT INTO router_request_logs VALUES (7, 'zai/glm')")
	db:user_version(5)
	local storage = RouterDatabase(db)
	t:has_error(function() storage:migrate() end)
	t:eq(db:user_version(), 5)
	t:tdeq(db:columns("router_request_logs"), {"id", "model"})
	t:eq(db:query("SELECT model FROM router_request_logs")[1].model, "zai/glm")
	db:close()
end

---@param t testing.T
function test.rejects_version_six_without_dropping_legacy_windows(t)
	local db = LjsqliteDatabase()
	db:open(":memory:")
	db:exec("CREATE TABLE router_channel_windows (channel_id INTEGER PRIMARY KEY, used_percent REAL)")
	db:exec("INSERT INTO router_channel_windows VALUES (1, 42.5)")
	db:user_version(6)
	local storage = RouterDatabase(db)
	t:has_error(function() storage:migrate() end)
	t:eq(db:user_version(), 6)
	t:eq(db:query("SELECT used_percent FROM router_channel_windows")[1].used_percent, 42.5)
	db:close()
end

---@param t testing.T
function test.rejects_version_seven_without_importing_oauth_files(t)
	local db = LjsqliteDatabase()
	db:open(":memory:")
	db:exec("CREATE TABLE router_channels (id INTEGER PRIMARY KEY, config TEXT)")
	db:exec([[INSERT INTO router_channels VALUES (1, '{"auth_path":"legacy.lua"}')]])
	db:user_version(7)
	local storage = RouterDatabase(db)
	t:has_error(function() storage:migrate() end)
	t:eq(db:user_version(), 7)
	t:eq(db:query("SELECT config FROM router_channels")[1].config, '{"auth_path":"legacy.lua"}')
	t:eq(#db:query("SELECT name FROM sqlite_master WHERE name = 'router_oauth_credentials'"), 0)
	db:close()
end

return test
