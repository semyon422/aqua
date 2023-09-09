local synctable = require("synctable")
local table_util = require("table_util")
local Thread = require("thread.Thread")

local FakeLoveThread = require("tests.thread.FakeLoveThread")

local test = {}

function test.simple(t)
	local thread

	local events = {}
	local _st = {}
	local st = synctable.new(_st, function(...)
		table.insert(events, {...})
		thread:sync(...)
	end)

	local fake = FakeLoveThread(1)
	thread = Thread(1, st, fake)

	t:assert(thread.idle)
	t:assert(not thread:isRunning())
	thread:start()
	t:assert(thread:isRunning())

	local result

	thread:execute({
		f = function(a, b) return a + b end,
		args = {1, 2, n = 3},
		result = function(res) result = res end,
		trace = "trace",
	})
	t:assert(not thread.idle)

	t:eq(#fake.inputChannel, 1)

	local t_res = table_util.pack(true, 3)
	t_res.name = "result"
	fake:pushOutput(t_res)

	thread:update()
	t:assert(thread.idle)

	t:eq(result, 3)

	thread:pushStop()
	t:eq(#fake.inputChannel, 2)

	st.a = 1
	t:eq(#fake.inputChannel, 3)

	local t_res = table_util.pack(true, 3)
	t_res.name = "result"
	fake:pushOutput({
		name = "synctable",
		n = 4,
		{}, "b", 2, false
	})

	thread:update()

	t:eq(st.b, 2)

	thread:updateLastTime(0)
end

return test
