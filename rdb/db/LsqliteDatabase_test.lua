if not pcall(require, "rdb.db.LsqliteDatabase") then
	return {}
end

local LsqliteDatabase = require("rdb.db.LsqliteDatabase")
local db_tests = require("rdb.db.tests")

---@type {[string]: fun(t: testing.T)}
local test = {}

for k, v in pairs(db_tests) do
	test[k] = function(t)
		local db = LsqliteDatabase()
		db:open(":memory:")
		v(t, db)
		db:close()
	end
end

return test
