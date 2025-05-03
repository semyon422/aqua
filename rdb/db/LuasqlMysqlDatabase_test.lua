if not pcall(require, "rdb.db.LuasqlMysqlDatabase") then
	return {}
end

local LuasqlMysqlDatabase = require("rdb.db.LuasqlMysqlDatabase")
local db_tests = require("rdb.db.tests")
local mysql_tests = require("rdb.db.mysql_tests")

---@type {[string]: fun(t: testing.T)}
local test = {}

local db = LuasqlMysqlDatabase()
local ok, err = db:open("test", "username", "password", "127.0.0.1", 3306)
if not ok then
	return
end

for _, tests in ipairs({db_tests, mysql_tests}) do
	for k, v in pairs(tests) do
		test[k] = function(t)
			local db = LuasqlMysqlDatabase()
			db:open("test", "username", "password", "127.0.0.1", 3306)
			v(t, db)
			db:close()
		end
	end
end

return test
