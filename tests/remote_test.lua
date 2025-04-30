local remote = require("remote")
local class = require("class")
local table_util = require("table_util")

local no_coder = {}
function no_coder.encode(v) return v end
function no_coder.decode(v) return v end

local Peer = class()

function Peer:send(data)
	table.insert(self, data)
end

local test = {}

function test.basic()
	remote.set_coder(no_coder)

	local epeer = Peer()
	local peer = remote.peer(epeer)

	coroutine.wrap(function(...)
		local res = peer.add(1, 2)
		assert(res == 3)
	end)()

	assert(#epeer == 1)
	assert(table_util.deepequal(epeer[1], {
		1,
		2,
		n = 2,
		id = 1,
		name = "add",
	}))

	local handlers = {}
	function handlers.add(_peer, a, b)
		return a + b
	end

	remote.receive(epeer[1], epeer, handlers)

	assert(#epeer == 2)
	assert(table_util.deepequal(epeer[2], {
		3,
		n = 1,
		id = 1,
	}))

	remote.receive(epeer[2], epeer, handlers)
end

function test.basic_no_return()
	remote.set_coder(no_coder)

	local epeer = Peer()
	local peer = remote.peer(epeer)

	coroutine.wrap(function(...)
		local res = peer._add(1, 2)
		assert(res == nil)
	end)()

	assert(#epeer == 1)
	assert(table_util.deepequal(epeer[1], {
		1,
		2,
		n = 2,
		-- id = 1,
		name = "add",
	}))

	local handlers = {}
	function handlers.add(_peer, a, b)
		return a + b
	end

	remote.receive(epeer[1], epeer, handlers)

	assert(#epeer == 1)
end

return test
