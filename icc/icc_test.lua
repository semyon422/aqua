local Remote = require("icc.Remote")
local RemoteHandler = require("icc.RemoteHandler")
local TaskHandler = require("icc.TaskHandler")
local QueuePeer = require("icc.QueuePeer")
local Message = require("icc.Message")
local Queue = require("icc.Queue")
local Queues = require("icc.Queues")
local QueuePeer = require("icc.QueuePeer")

local test = {}

---@param t testing.T
function test.all(t)
	local tbl = {}
	tbl.obj = {}
	function tbl.obj:func(a, b)
		return a + b
	end

	local th = TaskHandler(RemoteHandler(tbl))
	local peer = QueuePeer()
	local remote = Remote(th, peer)

	local done = false
	coroutine.wrap(function()
		local res = remote.obj:func(1, 2)
		t:eq(res, 3)
		done = true
	end)()

	t:eq(peer:count(), 1)
	t:tdeq(peer:get(1), Message(1, nil, {"obj", "func"}, true, 1, 2))

	th:handleCall(peer, {}, peer:get(1))

	t:eq(peer:count(), 2)
	t:tdeq(peer:get(2), Message(1, true, true, 3))

	th:handleReturn(peer:get(2))

	t:assert(done)
end

---@param t testing.T
function test.context_queue(t)
	---@type {[string]: icc.IQueue}
	local _queues = {}
	local function queue_factory(sid)
		if not _queues[sid] then
			_queues[sid] = Queue()
		end
		return _queues[sid]
	end

	local queues = Queues(queue_factory)

	-- Context A setup
	local tbl_a = {}
	local th_a = TaskHandler(RemoteHandler(tbl_a))
	local sid_a = "A"

	-- Context B setup
	local tbl_b = {
		add = function(self, x, y) return x + y end
	}
	local th_b = TaskHandler(RemoteHandler(tbl_b))
	local sid_b = "B"

	-- A wants to call B
	local peer_b_from_a = queues:getPeer(sid_b, sid_a)
	local remote_b_from_a = Remote(th_a, peer_b_from_a)

	---@type any
	local result
	local done = false
	coroutine.wrap(function()
		result = remote_b_from_a:add(10, 20)
		done = true
	end)()

	-- A's call should be in B's queue as PackedMessage
	t:eq(queues:count(sid_b), 1)
	local msg_call, return_peer = queues:pop(sid_b)
	---@cast msg_call -?
	---@cast return_peer -?
	t:tdeq(msg_call[1], {"add"})

	-- B handles the call
	th_b:handle(return_peer, {}, msg_call)

	-- B's response should be in A's queue as PackedMessage
	t:eq(queues:count(sid_a), 1)
	local packed_return, no_peer = queues:pop(sid_a)
	---@cast packed_return -?
	t:eq(packed_return.ret, true)
	t:eq(no_peer, nil)

	-- A handles the return
	th_a:handleReturn(packed_return)

	t:assert(done)
	t:eq(result, 30)
end

---@param t testing.T
function test.client_proxy_bug(t)
	local task_handler = TaskHandler({}, "server")

	local real_peer = QueuePeer()
	local real_remote = Remote(task_handler, real_peer)

	local remote_validation = {
		remote = real_remote,
		obj = {
			remote = real_remote.obj,
			test = function(self, ...)
				self.remote:test(...)
			end,
		}
	}

	local msg = Message(nil, nil, {"obj", "test"}, true, {})

	local handler = RemoteHandler(remote_validation)
	TaskHandler(handler, "client-proxy"):handleCall(QueuePeer(), {}, msg)

	t:tdeq(real_peer:get(1), {{"obj", "test"}, true, {}, id = 1, n = 3})
end

return test
