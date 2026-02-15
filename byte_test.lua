local byte = require("byte")

local test = {}

-- TODO: rewrite tests

---@param t testing.T
function test.all(t)
	local b = byte.buffer(8)
	assert(b.size == 8)
	assert(b.total(), 8)

	b:fill("\x01\x23\x45\x67\x89\xAB\xCD\xEF")
	assert(b.offset == 8)

	b:resize(16)
	assert(b.size == 16)
	assert(b.total(), 16)

	b:fill("\x62\x79\x74\x65\0\0\0\0")
	assert(b.offset == 16)

	b:seek(0)
	assert(b.offset == 0)

	assert(b:read("i32") == 0x67452301)
	assert(b.offset == 4)

	assert(not b:is_be())
	b:set_be(true)
	assert(b:is_be())

	assert(b:read("i32") == byte.to_signed(0x89ABCDEF, 4))
	assert(b.offset == 8)

	b:seek(0)
	b:write("f64", math.pi)
	b:seek(0)
	assert(b:read("f64") == math.pi)

	assert(b:string(8, true) == "byte")
	b:seek(8)
	assert(b:string(8) == "byte\0\0\0\0")

	b:free()
	assert(b.offset == 0)
	assert(b.size == 0)

	assert(b.total(), 0)
end

---@param t testing.T
function test.seeker(t)
	local buf = byte.buffer(10)
	local f = byte.stretchy_seeker(buf, 100)

	assert(f(1))
	assert(buf.offset == 1)
	assert(buf.size == 10)
	assert(f(10))
	assert(buf.offset == 11)
	assert(buf.size == 20)
	assert(f(40))
	assert(buf.offset == 51)
	assert(buf.size == 51)
	assert(f(1))
	assert(buf.offset == 52)
	assert(buf.size == 100)
	assert(not f(50))
	assert(buf.offset == 52)
	assert(buf.size == 100)
end

---@param t testing.T
function test.apply_1(t)
	local rets = {10, 100}
	local ok, size, ret1, ret2 = byte.apply(function(bytes)
		if bytes == 0 then return {} end
		return table.remove(rets)
	end, function(init)
		return init + coroutine.yield(1) + coroutine.yield(2), "test"
	end, 1000)

	assert(ok == true)
	assert(size == 3)
	assert(ret1 == 1110)
	assert(ret2 == "test")
end

---@param t testing.T
function test.apply_2(t)
	local rets = {10, nil}
	local ok, size, ret = byte.apply(function(bytes)
		if bytes == 0 then return {} end
		return table.remove(rets)
	end, function()
		return coroutine.yield(1) + coroutine.yield(2)
	end)

	assert(ok == false)
	assert(size == 1)
	assert(ret == nil)
end

return test
