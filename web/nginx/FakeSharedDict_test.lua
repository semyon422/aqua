local FakeSharedDict = require("web.nginx.FakeSharedDict")

local test = {}

---@param t testing.T
function test.basic_get_set(t)
	local dict = FakeSharedDict()
	dict:set("foo", "bar", 0, 123)
	local val, flags = dict:get("foo")
	t:eq(val, "bar")
	t:eq(flags, 123)
end

---@param t testing.T
function test.expiration(t)
	local now = 1000
	local dict = FakeSharedDict(function() return now end)

	dict:set("expires", "soon", 10)
	t:eq(dict:get("expires"), "soon")

	now = 1011
	t:eq(dict:get("expires"), nil)

	local val, flags, stale = dict:get_stale("expires")
	t:eq(val, "soon")
	t:eq(stale, true)
end

---@param t testing.T
function test.add_replace(t)
	local dict = FakeSharedDict()

	local ok, err = dict:add("key", "val1")
	t:eq(ok, true)

	ok, err = dict:add("key", "val2")
	t:eq(ok, false)
	t:eq(err, "exists")

	ok, err = dict:replace("key", "val3")
	t:eq(ok, true)
	t:eq(dict:get("key"), "val3")

	ok, err = dict:replace("nonexistent", "val")
	t:eq(ok, false)
	t:eq(err, "not found")
end

---@param t testing.T
function test.incr(t)
	local dict = FakeSharedDict()

	-- Case: not found, no init
	local val, err = dict:incr("counter", 1)
	t:eq(val, nil)
	t:eq(err, "not found")

	-- Case: not found, with init
	val, err = dict:incr("counter", 1, 10)
	t:eq(val, 11)
	t:eq(dict:get("counter"), 11)

	-- Case: increment existing
	val, err = dict:incr("counter", 5)
	t:eq(val, 16)

	-- Case: not a number
	dict:set("nan", "hello")
	val, err = dict:incr("nan", 1)
	t:eq(val, nil)
	t:eq(err, "not a number")
end

---@param t testing.T
function test.lists(t)
	local dict = FakeSharedDict()

	dict:lpush("list", "b")
	dict:lpush("list", "a")
	dict:rpush("list", "c")

	t:eq(dict:llen("list"), 3)
	t:eq(dict:lpop("list"), "a")
	t:eq(dict:rpop("list"), "c")
	t:eq(dict:lpop("list"), "b")
	t:eq(dict:lpop("list"), nil)
end

---@param t testing.T
function test.flush_and_keys(t)
	local dict = FakeSharedDict()
	dict:set("a", 1)
	dict:set("b", 2)
	dict:set("c", 3)

	local keys = dict:get_keys(0)
	table.sort(keys)
	t:eq(#keys, 3)
	t:eq(keys[1], "a")
	t:eq(keys[2], "b")
	t:eq(keys[3], "c")

	dict:flush_all()
	t:eq(#dict:get_keys(0), 0)
end

---@param t testing.T
function test.ttl_and_expire(t)
	local now = 1000
	local dict = FakeSharedDict(function() return now end)

	dict:set("key", "val", 10)
	t:eq(dict:ttl("key"), 10)

	dict:expire("key", 20)
	t:eq(dict:ttl("key"), 20)

	now = 1015
	t:eq(dict:ttl("key"), 5)

	dict:expire("key", 0) -- persistent
	t:eq(dict:ttl("key"), 0)
end

return test
