local rbtree = require("rbtree")

local test = {}

function test.string()
	local tree = rbtree.new()
	tree:insert(1)
	tree:insert(2)
	assert(tree:tostring() == "⚫ 1\n  🔴 2")
end

function test.valid_1()
	local tree = rbtree.new()
	tree:insert(1)
	tree:insert(2)
	tree:remove(1)
	assert(tree:is_valid())
end

function test.valid_2()
	local tree = rbtree.new()
	for i = 1, 3 do
		tree:insert(i)
	end
	assert(tree:is_valid())
	assert(tree.root:next().key == 3)
	assert(tree.root:prev().key == 1)
	assert(not tree:max():next())
	assert(not tree:min():prev())
end

function test.valid_3()
	local tree = rbtree.new()
	tree:insert(10)
	tree:insert(9)
	tree:insert(8)
	tree:insert(7)
	tree:remove(10)
	assert(tree:is_valid())
end

function test.invalid_root_color()
	local tree = rbtree.new()
	for i = 1, 3 do
		tree:insert(i)
	end
	tree.root.color = 1
	assert(not tree:is_valid())
end

--[[
  ⚫ 1
⚫ 2
    🔴 3
  ⚫ 4
    🔴 5
]]
function test.invalid_red_red()
	local tree = rbtree.new()
	for i = 1, 5 do
		tree:insert(i)
	end
	assert(tree.root.right.key == 4)
	tree.root.right.color = 1
	assert(not tree:is_valid())
end

function test.invalid_unbalanced()
	local tree = rbtree.new()
	for i = 1, 5 do
		tree:insert(i)
	end
	tree.root.left = nil
	assert(not tree:is_valid())
end

local function range(n)
	local t = {}
	for i = 1, n do
		t[i] = i
	end
	return t
end

local function shuffle(t)
	for i = #t, 2, -1 do
		local j = math.random(i)
		t[i], t[j] = t[j], t[i]
	end
	return t
end

function test.valid_1000()
	local tree = rbtree.new()

	local N = 100
	math.randomseed(N)

	local nums = {}
	for i = 1, N do
		table.insert(nums, i)
	end

	for _, v in ipairs(shuffle(range(N))) do
		tree:insert(v)
		assert(tree:is_valid())
	end

	assert(tree.size == N)
	assert(tree.root)
	assert(tree:is_valid())
	assert(tree:min().key == 1)
	assert(tree:max().key == N)
	assert(tostring(tree.root) == "⚫ " .. tree.root.key)
	assert(tree:findex(50, function(key) return key end).key == 50)
	assert(not tree:insert(50))
	assert(not tree:remove(N + 1))

	local c = 0
	for node, key in tree:iter() do
		c = c + 1
		assert(c == key)
	end
	assert(c == N)

	for i, v in ipairs(shuffle(range(N))) do
		tree:remove(v)
		assert(tree:is_valid())
	end

	assert(tree.size == 0)
	assert(not tree.root)
	assert(tree:is_valid())
end

return test
