local BroadcastingPeer = require("icc.BroadcastingPeer")
local TestNats = require("icc.nats.TestNats")
local Message = require("icc.Message")
local StringBufferPeer = require("icc.StringBufferPeer")

local buffer_peer = StringBufferPeer()

local test = {}

---@param t testing.T
function test.broadcast_send(t)
	local nc = TestNats()
	local peer = BroadcastingPeer(nc, "icc.broadcast.all")

	local msg = Message(nil, nil, {"multiplayer", "addMessage"}, "hello")
	local bytes = peer:send(msg)
	t:assert(bytes ~= nil)
	t:assert(bytes > 0)

	t:eq(#nc.published, 1)
	t:eq(nc.published[1].subject, "icc.broadcast.all")

	-- Verify payload is decodable
	local decoded = buffer_peer:decode(nc.published[1].payload)
	t:assert(decoded)
	t:tdeq(decoded[1], {"multiplayer", "addMessage"})
	t:eq(decoded[2], "hello")
end

---@param t testing.T
function test.broadcast_fan_out(t)
	local nc = TestNats()

	local a_received = {}
	local b_received = {}
	nc:subscribe("icc.broadcast.all", function(msg)
		table.insert(a_received, msg)
	end)
	nc:subscribe("icc.broadcast.all", function(msg)
		table.insert(b_received, msg)
	end)

	local peer = BroadcastingPeer(nc, "icc.broadcast.all")
	peer:send(Message(nil, nil, {"multiplayer", "setUsers"}, {id = 1}))

	nc:flush()

	-- Both subscribers get the message
	t:eq(#a_received, 1)
	t:eq(#b_received, 1)
	t:eq(a_received[1].subject, "icc.broadcast.all")
	t:eq(b_received[1].subject, "icc.broadcast.all")
end

---@param t testing.T
function test.broadcast_room(t)
	local nc = TestNats()

	local room5_received = {}
	local room10_received = {}
	nc:subscribe("icc.broadcast.room.5", function(msg)
		table.insert(room5_received, msg)
	end)
	nc:subscribe("icc.broadcast.room.10", function(msg)
		table.insert(room10_received, msg)
	end)

	-- Broadcast to room 5 only
	local peer = BroadcastingPeer(nc, "icc.broadcast.room.5")
	peer:send(Message(nil, nil, {"multiplayer", "addMessage"}, "hello room 5"))

	nc:flush()

	t:eq(#room5_received, 1)
	t:eq(#room10_received, 0)
end

return test
