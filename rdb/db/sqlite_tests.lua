---@type {[string]: fun(t: testing.T, db: rdb.IDatabase)}
local sqlite_tests = {}

function sqlite_tests.insert_returning(t, db)
	db:exec([[
DROP TABLE IF EXISTS `test`;
CREATE TABLE `test` (
	`id` INTEGER PRIMARY KEY,
	`count` INTEGER
);
]])

	local rows = db:query("INSERT INTO `test` (`count`) VALUES (10), (20) RETURNING *")

	t:tdeq(rows, {{id = 1, count = 10}, {id = 2, count = 20}})
end

return sqlite_tests
