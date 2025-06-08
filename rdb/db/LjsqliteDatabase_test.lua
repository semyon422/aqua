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

return test
