-- disabled because of https://github.com/lunarmodules/luasql/issues/179
do return end

if not pcall(require, "rdb.db.LuasqlSqliteDatabase") then
	return {}
end

local LuasqlSqliteDatabase = require("rdb.db.LuasqlSqliteDatabase")
local db_tests = require("rdb.db.tests")
local sqlite_tests = require("rdb.db.sqlite_tests")

---@type {[string]: fun(t: testing.T)}
local test = {}

for _, tests in ipairs({db_tests, sqlite_tests}) do
	for k, v in pairs(tests) do
		test[k] = function(t)
			local db = LuasqlSqliteDatabase()
			db:open(":memory:")
			v(t, db)
			db:close()
		end
	end
end

return test
