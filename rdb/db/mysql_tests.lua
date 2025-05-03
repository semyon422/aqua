---@type {[string]: fun(t: testing.T, db: rdb.IDatabase)}
local mysql_tests = {}

function mysql_tests.insert_returning(t, db)
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
end

return mysql_tests
