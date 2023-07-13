local rbtree = require("rbtree")

do
	local tree = rbtree.new()
	tree:insert(1)
	tree:insert(2)
	tree:remove(1)
	assert(tree:is_valid())
end

do
	local tree = rbtree.new()
	tree:insert(10)
	tree:insert(9)
	tree:insert(8)
	tree:insert(7)
	tree:remove(10)
	assert(tree:is_valid())
end

local tree = rbtree.new()

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

local N = 1000
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

for i, v in ipairs(shuffle(range(N))) do
	tree:remove(v)
	assert(tree:is_valid())
end

assert(tree.size == 0)
assert(not tree.root)
assert(tree:is_valid())
