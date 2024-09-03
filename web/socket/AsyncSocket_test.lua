local AsyncSocket = require("web.socket.AsyncSocket")
local FakeSocket = require("web.socket.FakeSocket")

local test = {}

local FAKE_SIZE = 0
local FAKE_DATA = ""

local SIZE_1 = 10
local SIZE_2 = 20
local DATA_1 = "qwe"
local DATA_2 = "qwerty"

function test.read_success(t)
	local soc = FakeSocket(DATA_1)
	local asoc = AsyncSocket(soc)
	local data = asoc:read(FAKE_SIZE)
	t:eq(data, DATA_1)
end

function test.read_timeout(t)
	local soc = FakeSocket(DATA_1, "timeout")
	local asoc = AsyncSocket(soc)

	local data = ""
	local co = coroutine.create(function()
		data = asoc:read(FAKE_SIZE)
	end)

	coroutine.resume(co)
	t:eq(data, "")
	soc:new(DATA_2)
	coroutine.resume(co)
	t:eq(data, DATA_1 .. DATA_2)
end

function test.read_closed(t)
	local soc = FakeSocket(DATA_1, "closed")
	local asoc = AsyncSocket(soc)

	local data, err, partial = asoc:read(FAKE_SIZE)
	t:eq(data, nil)
	t:eq(err, "closed")
	t:eq(partial, DATA_1)
end

function test.write_success(t)
	local soc = FakeSocket(SIZE_1)
	local asoc = AsyncSocket(soc)
	local size = asoc:write(FAKE_DATA)
	t:eq(size, SIZE_1)
end

function test.write_timeout(t)
	local soc = FakeSocket(SIZE_1, "timeout")
	local asoc = AsyncSocket(soc)

	local size = 0
	local co = coroutine.create(function()
		size = asoc:write(FAKE_DATA)
	end)

	coroutine.resume(co)
	t:eq(size, 0)
	soc:new(SIZE_1 + SIZE_2)
	coroutine.resume(co)
	t:eq(size, SIZE_1 + SIZE_2)
end

function test.write_closed(t)
	local soc = FakeSocket(SIZE_1, "closed")
	local asoc = AsyncSocket(soc)

	local data, err, partial = asoc:write(FAKE_DATA)
	t:eq(data, nil)
	t:eq(err, "closed")
	t:eq(partial, SIZE_1)
end

return test
