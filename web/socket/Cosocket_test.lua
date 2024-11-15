local Cosocket = require("web.socket.Cosocket")
local FakeSocket = require("web.socket.FakeSocket")

local test = {}

local FAKE_SIZE = 0
local FAKE_DATA = ""

local SIZE_1 = 10
local SIZE_2 = 20
local DATA_1 = "qwe"
local DATA_2 = "qwerty"

function test.read_success(t)
	local soc = FakeSocket({{DATA_1}})
	local asoc = Cosocket(soc)
	local data = asoc:receive(FAKE_SIZE)
	t:eq(data, DATA_1)
end

function test.read_timeout(t)
	local soc = FakeSocket({
		{DATA_1, "timeout"},
		{DATA_2},
	})
	local asoc = Cosocket(soc)

	local data, err, partial = nil, nil, nil
	local co = coroutine.create(function()
		data, err, partial = asoc:receive(FAKE_SIZE)
	end)

	local _, timeout_on = assert(coroutine.resume(co))
	t:eq(timeout_on, "read")
	t:eq(data, nil)
	t:eq(err, nil)
	t:eq(partial, nil)
	_, timeout_on = assert(coroutine.resume(co))
	t:eq(timeout_on, nil)
	t:eq(data, DATA_1 .. DATA_2)
	t:eq(err, nil)
	t:eq(partial, nil)
end

function test.read_closed(t)
	local soc = FakeSocket({
		{DATA_1, "timeout"},
		{DATA_2, "closed"},
	})
	local asoc = Cosocket(soc)

	local data, err, partial = nil, nil, nil
	local co = coroutine.create(function()
		data, err, partial = asoc:receive(FAKE_SIZE)
	end)

	local _, timeout_on = assert(coroutine.resume(co))
	t:eq(timeout_on, "read")
	t:eq(data, nil)
	t:eq(err, nil)
	t:eq(partial, nil)
	_, timeout_on = assert(coroutine.resume(co))
	t:eq(timeout_on, nil)
	t:eq(data, nil)
	t:eq(err, "closed")
	t:eq(partial, DATA_1 .. DATA_2)
end

function test.write_success(t)
	local soc = FakeSocket({{SIZE_1}})
	local asoc = Cosocket(soc)
	local size = asoc:send(FAKE_DATA)
	t:eq(size, SIZE_1)
end

function test.write_timeout(t)
	local soc = FakeSocket({
		{SIZE_1, "timeout"},
		{SIZE_2},
	})
	local asoc = Cosocket(soc)

	local size, err, partial = 0, nil, nil
	local co = coroutine.create(function()
		size, err, partial = asoc:send(FAKE_DATA)
	end)

	local _, timeout_on = assert(coroutine.resume(co))
	t:eq(timeout_on, "write")
	t:eq(size, 0)
	t:eq(err, nil)
	t:eq(partial, nil)
	_, timeout_on = assert(coroutine.resume(co))
	t:eq(timeout_on, nil)
	t:eq(size, SIZE_2)
	t:eq(err, nil)
	t:eq(partial, nil)
end

function test.write_closed(t)
	local soc = FakeSocket({
		{SIZE_1, "timeout"},
		{SIZE_2, "closed"},
	})
	local asoc = Cosocket(soc)

	local size, err, partial = 0, nil, nil
	local co = coroutine.create(function()
		size, err, partial = asoc:send(FAKE_DATA)
	end)

	local _, timeout_on = assert(coroutine.resume(co))
	t:eq(timeout_on, "write")
	t:eq(size, 0)
	t:eq(err, nil)
	t:eq(partial, nil)
	_, timeout_on = assert(coroutine.resume(co))
	t:eq(timeout_on, nil)
	t:eq(size, nil)
	t:eq(err, "closed")
	t:eq(partial, SIZE_2)
end

return test
