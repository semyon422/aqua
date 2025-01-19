local TaskHandler = require("icc.TaskHandler")
local FuncHandler = require("icc.FuncHandler")
local FakePeer = require("icc.FakePeer")
local Message = require("icc.Message")

local test = {}

function test.basic(t)
	---@type icc.HandlerFunc
	local function handler(th, peer, a, b)
		return a + b
	end

	local th = TaskHandler(FuncHandler(handler))
	local peer = FakePeer()

	local done = false
	coroutine.wrap(function()
		local res = th:call(peer, 1, 2)
		t:eq(res, 3)
		done = true
	end)()

	t:eq(peer:count(), 1)
	t:tdeq(peer:get(1), Message(1, nil, 1, 2))

	th:handle(peer, peer:get(1))

	t:eq(peer:count(), 2)
	t:tdeq(peer:get(2), Message(1, true, 3))

	th:handleReturn(peer:get(2))
	t:assert(done)
end

function test.basic_no_return(t)
	local handled = false
	---@type icc.HandlerFunc
	local function handler(th, peer, a, b)
		handled = true
		return a + b
	end

	local th = TaskHandler(FuncHandler(handler))
	local peer = FakePeer()

	local done = false
	coroutine.wrap(function()
		local res = th:callnr(peer, 1, 2)
		t:eq(res, nil)
		done = true
	end)()

	t:eq(peer:count(), 1)
	t:tdeq(peer:get(1), Message(nil, nil, 1, 2))

	th:handle(peer, peer:get(1))

	t:eq(peer:count(), 1)
	t:assert(handled)
	t:assert(done)
end

function test.multiple(t)
	---@type icc.HandlerFunc
	local function handler1(th, peer, a)
		t:eq(a, "ab")
		return a .. "c"
	end

	---@type icc.HandlerFunc
	local function handler2(th, peer, a)
		t:eq(a, "a")
		local res = th:call(peer, a .. "b")
		t:eq(res, "abc")
		return res .. "d"
	end

	local th1 = TaskHandler(FuncHandler(handler1))
	local th2 = TaskHandler(FuncHandler(handler2))
	local peer1 = FakePeer()
	local peer2 = FakePeer()

	local done = false
	coroutine.wrap(function()
		local res = th1:call(peer1, "a")
		t:eq(res, "abcd")
		done = true
	end)()

	th2:handle(peer2, peer1:get(1))
	th1:handle(peer1, peer2:get(1))
	th2:handleReturn(peer1:get(2))
	th1:handleReturn(peer2:get(2))

	t:assert(done)
end

return test
