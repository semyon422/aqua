if not pcall(require, "rdb.db.LuasqlMysqlDatabase") then
	return {}
end

local LuasqlMysqlDatabase = require("rdb.db.LuasqlMysqlDatabase")
local db_tests = require("rdb.db.tests")

---@type {[string]: fun(t: testing.T)}
local test = {}

local function open_db(db)
	return db:open("test", "username", "password", "127.0.0.1", 3306)
end

function test.__check(t)
	local db = LuasqlMysqlDatabase()
	return open_db(db)
end

for k, v in pairs(db_tests) do
	test[k] = function(t)
		local db = LuasqlMysqlDatabase()
		open_db(db)
		v(t, db)
		db:close()
	end
end

function test.insert_returning(t)
	local db = LuasqlMysqlDatabase()
	open_db(db)

	db:exec([[
DROP TABLE IF EXISTS `test`;
CREATE TABLE `test` (
	`id` INT PRIMARY KEY AUTO_INCREMENT,
	`count` INT
);
]])

	db:columns("test")

	local rows = db:query("INSERT INTO `test` (`count`) VALUES (10), (20) RETURNING *")

	t:tdeq(rows, {{id = "1", count = "10"}, {id = "2", count = "20"}})

	db:close()
end

return test
