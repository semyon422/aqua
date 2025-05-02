if not pcall(require, "rdb.LuasqlSqliteDatabase") then
	return {}
end

local LuasqlSqliteDatabase = require("rdb.db.LuasqlSqliteDatabase")
local db_tests = require("rdb.db.tests")

---@type {[string]: fun(t: testing.T)}
local test = {}

for k, v in pairs(db_tests) do
	test[k] = function(t)
		local db = LuasqlSqliteDatabase()
		db:open(":memory:")
		v(t, db)
		db:close()
	end
end

return test
