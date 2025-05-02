if not pcall(require, "rdb.LuasqlMysqlDatabase") then
	return {}
end

local LuasqlMysqlDatabase = require("rdb.LuasqlMysqlDatabase")
local db_tests = require("rdb.db_tests")

---@type {[string]: fun(t: testing.T)}
local test = {}

for k, v in pairs(db_tests) do
	test[k] = function(t)
		local db = LuasqlMysqlDatabase()
		db:open("test", "username", "password", "127.0.0.1", 3306)
		v(t, db)
		db:close()
	end
end

return test
