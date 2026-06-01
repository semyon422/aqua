local NatsPeer = require("icc.nats.NatsPeer")
local TestNats = require("icc.nats.TestNats")
local Message = require("icc.Message")
local StringBufferPeer = require("icc.StringBufferPeer")

local buffer_peer = StringBufferPeer()

local test = {}

---@param t testing.T
function test.nats_peer_one_way(t)
	local nc = TestNats()
	local peer = NatsPeer(nc, "icc.inbox.caller", "1.2.3.4:1234")

	local msg = Message(nil, nil, {"multiplayer", "setRooms"}, true, {id = 1})
	peer:send(msg)

	t:eq(#nc.published, 1)
	t:eq(nc.published[1].subject, "icc.peer.1.2.3.4:1234")
	t:eq(nc.published[1].reply_to, nil) -- no msg.id, so no reply_to

	-- Verify payload is decodable
	local decoded = buffer_peer:decode(nc.published[1].payload)
	t:assert(decoded)
	t:tdeq(decoded[1], {"multiplayer", "setRooms"})
	t:eq(decoded[2], true)
end

---@param t testing.T
function test.nats_peer_two_way(t)
	local nc = TestNats()
	local peer = NatsPeer(nc, "icc.inbox.caller", "target:1234")

	-- Two-way call: msg has id, so reply_to is included
	local msg = Message(42, nil, {"add"}, true, 3, 7)
	peer:send(msg)

	t:eq(#nc.published, 1)
	t:eq(nc.published[1].subject, "icc.peer.target:1234")
	t:eq(nc.published[1].reply_to, "icc.inbox.caller.42")
end

---@param t testing.T
function test.nats_peer_reply(t)
	-- Reply peer: inbox=nil, target=reply_to subject
	local nc = TestNats()
	local peer = NatsPeer(nc, nil, "icc.inbox.caller.42")

	local msg = Message(42, true, 42)
	peer:send(msg)

	t:eq(#nc.published, 1)
	t:eq(nc.published[1].subject, "icc.inbox.caller.42")
	t:eq(nc.published[1].reply_to, nil) -- no inbox, no reply_to

	local decoded = buffer_peer:decode(nc.published[1].payload)
	t:eq(decoded.id, 42)
	t:assert(decoded.ret)
	t:eq(decoded[1], 42)
end

---@param t testing.T
function test.nats_peer_subscribe_delivery(t)
	local nc = TestNats()

	local received = {}
	nc:subscribe("icc.peer.1.2.3.4:1234", function(msg)
		table.insert(received, msg)
	end)

	local peer = NatsPeer(nc, "icc.inbox.caller", "1.2.3.4:1234")
	local message = Message(nil, nil, {"multiplayer", "setRooms"}, true, {id = 1})
	peer:send(message)

	-- TestNats uses pending queue — flush to deliver
	nc:flush()

	t:eq(#received, 1)
	local decoded = buffer_peer:decode(received[1].payload)
	t:tdeq(decoded[1], {"multiplayer", "setRooms"})
end

---@param t testing.T
function test.nats_peer_wildcard_subscribe(t)
	local nc = TestNats()

	local received = {}
	nc:subscribe("icc.peer.*", function(msg)
		table.insert(received, msg)
	end)

	-- Publish to different peers
	NatsPeer(nc, "icc.inbox.caller", "peer1"):send(Message(nil, nil, {"a"}, true))
	NatsPeer(nc, "icc.inbox.caller", "peer2"):send(Message(nil, nil, {"b"}, true))

	nc:flush()

	t:eq(#received, 2)
	t:eq(received[1].subject, "icc.peer.peer1")
	t:eq(received[2].subject, "icc.peer.peer2")
end

---@param t testing.T
function test.test_nats_multi_wildcard(t)
	local nc = TestNats()

	local received = {}
	nc:subscribe("icc.peer.>", function(msg)
		table.insert(received, msg)
	end)

	-- Multi-level subjects match with `>`
	NatsPeer(nc, "icc.inbox.caller", "a.b"):send(Message(nil, nil, {"x"}, true))
	NatsPeer(nc, "icc.inbox.caller", "a.b.c"):send(Message(nil, nil, {"y"}, true))

	nc:flush()

	t:eq(#received, 2)
	t:eq(received[1].subject, "icc.peer.a.b")
	t:eq(received[2].subject, "icc.peer.a.b.c")
end

---@param t testing.T
function test.test_nats_unsubscribe(t)
	local nc = TestNats()

	local received = {}
	local sid
	_, _, sid = nc:subscribe("test.*", function(msg)
		table.insert(received, msg)
	end)

	nc:publish({subject = "test.a", payload = "1"})
	nc:flush()
	t:eq(#received, 1)

	nc:unsubscribe(sid)
	nc:publish({subject = "test.b", payload = "2"})
	nc:flush()
	t:eq(#received, 1) -- no new delivery
end

---@param t testing.T
function test.test_nats_multiple_subscribers_same_subject(t)
	local nc = TestNats()

	local a_received = {}
	local b_received = {}
	local _, _, sid_a = nc:subscribe("test.>", function(msg)
		table.insert(a_received, msg)
	end)
	local _, _, sid_b = nc:subscribe("test.>", function(msg)
		table.insert(b_received, msg)
	end)

	nc:publish({subject = "test.foo", payload = "hello"})
	nc:flush()

	-- Both subscribers get the message
	t:eq(#a_received, 1)
	t:eq(#b_received, 1)

	-- Unsubscribe only B
	nc:unsubscribe(sid_b)
	nc:publish({subject = "test.bar", payload = "world"})
	nc:flush()

	-- A still receives, B does not
	t:eq(#a_received, 2)
	t:eq(#b_received, 1)
end

---@param t testing.T
function test.test_nats_health(t)
	local nc = TestNats()
	t:assert(nc:health())
end

return test
