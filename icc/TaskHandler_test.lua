local TaskHandler = require("icc.TaskHandler")
local FuncHandler = require("icc.FuncHandler")
local QueuePeer = require("icc.QueuePeer")
local Message = require("icc.Message")

local test = {}

---@param t testing.T
function test.basic(t)
	---@type icc.HandlerFunc
	local function handler(ctx, a, b)
		return a + b
	end

	local th = TaskHandler(FuncHandler(handler))
	local peer = QueuePeer()

	local done = false
	coroutine.wrap(function()
		local res = th:call(peer, 1, 2)
		t:eq(res, 3)
		done = true
	end)()

	t:eq(peer:count(), 1)
	t:tdeq(peer:get(1), Message(1, nil, 1, 2))

	th:handleCall(peer, {}, peer:get(1))

	t:eq(peer:count(), 2)
	t:tdeq(peer:get(2), Message(1, true, true, 3))

	th:handleReturn(peer:get(2))
	t:assert(done)
end

---@param t testing.T
function test.basic_no_return(t)
	local handled = false
	---@type icc.HandlerFunc
	local function handler(ctx, a, b)
		handled = true
		return a + b
	end

	local th = TaskHandler(FuncHandler(handler))
	local peer = QueuePeer()

	local done = false
	coroutine.wrap(function()
		local res = th:callnr(peer, 1, 2)
		t:eq(res, nil)
		done = true
	end)()

	t:eq(peer:count(), 1)
	t:tdeq(peer:get(1), Message(nil, nil, 1, 2))

	th:handleCall(peer, {}, peer:get(1))

	t:eq(peer:count(), 1)
	t:assert(handled)
	t:assert(done)
end

---@param t testing.T
function test.multiple(t)
	---@type icc.HandlerFunc
	local function handler1(ctx, a)
		t:eq(a, "ab")
		return a .. "c"
	end

	---@type icc.HandlerFunc
	local function handler2(ctx, a)
		---@cast ctx {th: icc.TaskHandler, peer: icc.IPeer}
		t:eq(a, "a")
		local res = ctx.th:call(ctx.peer, a .. "b")
		t:eq(res, "abc")
		return res .. "d"
	end

	local th1 = TaskHandler(FuncHandler(handler1))
	local th2 = TaskHandler(FuncHandler(handler2))
	local peer1 = QueuePeer()
	local peer2 = QueuePeer()

	local done = false
	coroutine.wrap(function()
		local res = th1:call(peer1, "a")
		t:eq(res, "abcd")
		done = true
	end)()

	local ctx = {
		th = th2,
		peer = peer2,
	}

	th2:handleCall(peer2, ctx, peer1:get(1))
	th1:handleCall(peer1, {}, peer2:get(1))
	th2:handleReturn(peer1:get(2))
	th1:handleReturn(peer2:get(2))

	t:assert(done)
end

---@param t testing.T
function test.error(t)
	---@type icc.HandlerFunc
	local function handler(ctx)
		error("msg")
	end

	local th = TaskHandler(FuncHandler(handler))
	local peer = QueuePeer()

	local done = false
	coroutine.wrap(function()
		local ok, err = pcall(th.call, th, peer)
		t:eq(ok, false)
		done = true
	end)()

	t:eq(peer:count(), 1)
	t:tdeq(peer:get(1), Message(1, nil))

	th:handleCall(peer, {}, peer:get(1))

	t:eq(peer:count(), 2)

	local msg = peer:get(2)
	t:eq(msg.id, 1)
	t:eq(msg.n, 2)
	t:eq(msg.ret, true)
	t:eq(msg[1], false)
	t:assert(msg[2]:match("_test.lua:%d+: msg"))

	th:handleReturn(peer:get(2))
	t:assert(done)
end

---@param t testing.T
function test.error_no_return(t)
	---@type icc.HandlerFunc
	local function handler(ctx)
		error("msg")
	end

	local th = TaskHandler(FuncHandler(handler))
	local peer = QueuePeer()

	local done = false
	coroutine.wrap(function()
		th:callnr(peer)
		done = true
	end)()

	t:eq(peer:count(), 1)
	t:tdeq(peer:get(1), Message(nil, nil))

	t:assert(done)

	local ok, err = pcall(th.handleCall, th, peer, {}, peer:get(1))
	t:eq(ok, false)
	t:assert(err and err:match("_test.lua:%d+: msg"))
end

---@param t testing.T
function test.error_after_resume(t)
	local th = TaskHandler(FuncHandler(function() end))
	local peer = QueuePeer()

	local done = false
	coroutine.wrap(function()
		th:call(peer)
		error("msg")
		done = true
	end)()

	t:eq(peer:count(), 1)
	t:tdeq(peer:get(1), Message(1, nil))

	th:handleCall(peer, {}, peer:get(1))

	t:eq(peer:count(), 2)

	local ok, err = pcall(th.handleReturn, th, peer:get(2))
	t:eq(ok, false)
	t:assert(err and err:match("_test.lua:%d+: msg"))
	t:assert(err and err:match("stack traceback"))

	t:assert(not done)
end

---@param t testing.T
function test.error_send_closed(t)
	local th = TaskHandler(FuncHandler(function() end))
	local peer = QueuePeer()

	function peer:send()
		return nil, "closed"
	end

	local done = false
	local co = coroutine.create(function()
		th:call(peer)
		done = true
	end)

	local ok, err = coroutine.resume(co)

	t:eq(ok, false)
	t:assert(err and err:match("_test.lua:%d+: closed"))
	t:assert(err and err:match("stack traceback"))

	t:assert(not done)
end

---@param t testing.T
function test.error_timeout(t)
	local th = TaskHandler(FuncHandler(function() end))
	local peer = QueuePeer()

	th.timeout = 0

	local done = false
	local co = coroutine.create(function()
		th:call(peer)
		done = true
	end)

	assert(coroutine.resume(co))

	local ok, err = pcall(th.update, th)

	t:eq(ok, false)
	t:assert(err and err:match("_test.lua:%d+: timeout"))
	t:assert(err and err:match("stack traceback"))

	t:assert(not done)
end

return test
