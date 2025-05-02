---@type {[string]: fun(t: testing.T, db: rdb.IDatabase)}
local tests = {}

function tests.bind_string(t, db)
	t:tdeq(db:query("SELECT ? AS hello;", {"world"}), {{hello = "world"}})
end

function tests.bind_bytes(t, db)
	---@type string[]
	local buf = {}
	for c = 0, 0xFF do
		buf[c + 1] = string.char(c)
	end
	local str = table.concat(buf)

	t:tdeq(db:query("SELECT ? AS bytes;", {str}), {{bytes = str}})
end

function tests.columns(t, db)
	db:exec("DROP TABLE IF EXISTS `test`;")
	db:exec("CREATE TABLE `test` (`count` INT);")

	t:tdeq(db:columns("test"), {"count"})
end

function tests.begin_commit(t, db)
	db:exec("BEGIN")
	db:exec("COMMIT;")
end

return tests
