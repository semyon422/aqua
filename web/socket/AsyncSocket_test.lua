local AsyncSocket = require("web.socket.AsyncSocket")
local FakeSocket = require("web.socket.FakeSocket")

local test = {}

local FAKE_SIZE = 0
local FAKE_DATA = ""

function test.read_success(t)
	local soc = FakeSocket("data")
	local asoc = AsyncSocket(soc)
	local data = asoc:read(FAKE_SIZE)
	t:eq(data, "data")
end

function test.read_timeout(t)
	local soc = FakeSocket("partial", "timeout")
	local asoc = AsyncSocket(soc)

	local data = ""
	local co = coroutine.create(function()
		data = asoc:read(FAKE_SIZE)
	end)

	coroutine.resume(co)
	t:eq(data, "")
	soc:new("data")
	coroutine.resume(co)
	t:eq(data, "partialdata")
end

function test.read_closed(t)
	local soc = FakeSocket("partial", "closed")
	local asoc = AsyncSocket(soc)

	local data, err, partial = asoc:read(FAKE_SIZE)
	t:eq(data, nil)
	t:eq(err, "closed")
	t:eq(partial, "partial")
end

function test.write_success(t)
	local soc = FakeSocket(4)
	local asoc = AsyncSocket(soc)
	local size = asoc:write(FAKE_DATA)
	t:eq(size, 4)
end

function test.write_timeout(t)
	local soc = FakeSocket(7, "timeout")
	local asoc = AsyncSocket(soc)

	local size = 0
	local co = coroutine.create(function()
		size = asoc:write(FAKE_DATA)
	end)

	coroutine.resume(co)
	t:eq(size, 0)
	soc:new(11)
	coroutine.resume(co)
	t:eq(size, 11)
end

function test.write_closed(t)
	local soc = FakeSocket(7, "closed")
	local asoc = AsyncSocket(soc)

	local data, err, partial = asoc:write(FAKE_DATA)
	t:eq(data, nil)
	t:eq(err, "closed")
	t:eq(partial, 7)
end

return test
