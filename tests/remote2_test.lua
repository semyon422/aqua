local remote = require("remote2")
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

	local peer = Peer()

	local done = false
	coroutine.wrap(function(...)
		local res = remote.call(peer, 1, 2)
		assert(res == 3)
		done = true
	end)()

	assert(#peer == 1)
	assert(table_util.deepequal(peer[1], {
		1, 2,
		n = 2,
		id = 1,
	}))

	local function handler(_peer, a, b)
		return a + b
	end

	remote.receive(peer[1], peer, handler)

	assert(#peer == 2)
	assert(table_util.deepequal(peer[2], {
		3,
		n = 1,
		id = 1,
		ret = true,
	}))

	remote.receive(peer[2], peer, handler)
	assert(done)
end

function test.basic_no_return()
	remote.set_coder(no_coder)

	local peer = Peer()

	local done = false
	coroutine.wrap(function(...)
		local res = remote.callnr(peer, 1, 2)
		assert(res == nil)
		done = true
	end)()

	assert(#peer == 1)
	assert(table_util.deepequal(peer[1], {
		1, 2,
		n = 2,
		-- id = 1,
	}))

	local handled = false
	local function handler(_peer, a, b)
		handled = true
		return a + b
	end

	remote.receive(peer[1], peer, handler)

	assert(#peer == 1)
	assert(handled)
	assert(done)
end

-- not implemented yet
local function test_advanced()
	remote.set_coder(no_coder)

	local epeer = Peer()
	local peer = remote.peer(epeer)

	local done = false
	coroutine.wrap(function(...)
		local res = peer.q.w.e:add(1, 2)
		assert(res == 3)
		res = peer.q.w.e.sub(1, 2)
		assert(res == -1)
		done = true
	end)()

	assert(#epeer == 1)
	assert(table_util.deepequal(epeer[1], {
		{"q", "w", "e", "add", method = true}, 1, 2,
		n = 3,
		id = 1,
	}))

	local t = {q = {w = {e = {}}}}
	t.q.w.e.add = function(self, _peer, a, b)
		return a + b
	end
	t.q.w.e.sub = function(_peer, a, b)
		return a - b
	end
	local function handler(_epeer, info, ...)
		local __t, _t = nil, t
		for _, k in ipairs(info) do
			__t, _t = _t, _t[k]
		end
		local _peer = remote.peer(_epeer)
		if info.method then
			return _t(__t, _peer, ...)
		end
		return _t(_peer, ...)
	end

	remote.receive(epeer[1], epeer, handler)

	assert(#epeer == 2)
	assert(table_util.deepequal(epeer[2], {
		3,
		n = 1,
		id = 1,
		ret = true,
	}))

	remote.receive(epeer[2], epeer, handler)

	assert(#epeer == 3)
	assert(table_util.deepequal(epeer[3], {
		{"q", "w", "e", "sub"}, 1, 2,
		n = 3,
		id = 1,
	}))

	remote.receive(epeer[3], epeer, handler)

	assert(#epeer == 4)
	assert(table_util.deepequal(epeer[4], {
		-1,
		n = 1,
		id = 2,
		ret = true,
	}))

	assert(done)
end

return test
