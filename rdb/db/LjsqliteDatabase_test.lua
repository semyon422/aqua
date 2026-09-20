if not pcall(require, "rdb.db.LjsqliteDatabase") then
	return {}
end

local LjsqliteDatabase = require("rdb.db.LjsqliteDatabase")
local db_tests = require("rdb.db.tests")
local sqlite_tests = require("rdb.db.sqlite_tests")

---@type {[string]: fun(t: testing.T)}
local test = {}

for _, tests in ipairs({db_tests, sqlite_tests}) do
	for k, v in pairs(tests) do
		test[k] = function(t)
			local db = LjsqliteDatabase()
			db:open(":memory:")
			v(t, db)
			db:close()
		end
	end
end

---@param t testing.T
function test.closes_statement_after_step_error(t)
	local path = "tmp/LjsqliteDatabase_test.db"
	os.remove(path)
	os.remove(path .. "-wal")
	os.remove(path .. "-shm")

	local writer = LjsqliteDatabase()
	local blocked = LjsqliteDatabase()
	writer:open(path)
	blocked:open(path)
	writer:exec("PRAGMA journal_mode = WAL; PRAGMA busy_timeout = 1; CREATE TABLE test (id INTEGER)")
	blocked:exec("PRAGMA journal_mode = WAL; PRAGMA busy_timeout = 1; BEGIN")
	writer:exec("BEGIN; INSERT INTO test VALUES (1)")

	t:has_error(function()
		blocked:query("INSERT INTO test VALUES (2) RETURNING *")
	end)
	writer:exec("COMMIT")
	t:has_not_error(function()
		blocked:exec("COMMIT")
	end)

	writer:close()
	blocked:close()
	os.remove(path)
	os.remove(path .. "-wal")
	os.remove(path .. "-shm")
end

return test
