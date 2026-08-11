local synctable = require("synctable")
local table_util = require("table_util")

local test = {}

function test.new_basic()
	---@type any[][]
	local events = {}

	---@type synctable.Data
	local tbl = {1, {k = 1}}

	local st = synctable.new(tbl, function(path, k, v, is_path)
		table.insert(events, {path, k, v, is_path})
	end)

	-- Proxy values are intentionally dynamic and exposed through metamethods.
	---@diagnostic disable-next-line: no-unknown
	st[3] = 3
	st.a = {"a"}
	st.b = st.a

	assert(table_util.deepequal(events, {
		{{}, 1, 1, false},
		{{}, 2, {}, false},
		{{2}, "k", 1, false},
		{{}, 3, 3, false},
		{{}, "a", {}, false},
		{{"a"}, 1, "a", false},
		{{}, "b", {"a"}, true},
	}))

	---@type string[]
	local strings = {}

	---@type synctable.Data
	local new_tbl = {}
	-- LuaLS cannot infer the heterogeneous packed callback arguments.
	---@diagnostic disable-next-line: no-unknown
	for _, event in ipairs(events) do
		synctable.set(new_tbl, unpack(event))
		table.insert(strings, synctable.format("prefix", unpack(event)))
	end

	assert(table_util.deepequal(tbl, new_tbl))

	assert(table_util.deepequal(strings, {
		"prefix[1] = 1",
		"prefix[2] = {}",
		"prefix[2].k = 1",
		"prefix[3] = 3",
		"prefix.a = {}",
		'prefix.a[1] = "a"',
		"prefix.b = prefix.a",
	}))
end

return test
