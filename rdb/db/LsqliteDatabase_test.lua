if not pcall(require, "rdb.db.LsqliteDatabase") then
	return {}
end

local LsqliteDatabase = require("rdb.db.LsqliteDatabase")
local db_tests = require("rdb.db.tests")
local sqlite_tests = require("rdb.db.sqlite_tests")

---@type {[string]: fun(t: testing.T)}
local test = {}

for _, tests in ipairs({db_tests, sqlite_tests}) do
	for k, v in pairs(tests) do
		test[k] = function(t)
			local db = LsqliteDatabase()
			db:open(":memory:")
			v(t, db)
			db:close()
		end
	end
end

return test
