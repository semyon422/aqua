-- red-black tree

local Tree = {}
local Tree_mt = {__index = Tree}

local Node = {}
local Node_mt = {__index = Node}

local function rotate_left(tree, x)
	local p = x.parent
	local y = x.right

	if y.left then
		y.left.parent = x
	end
	x.right = y.left

	x.parent = y
	y.left = x

	y.parent = p
	if not p then
		tree.root = y
	elseif x == p.left then
		p.left = y
	else
		p.right = y
	end
end

local function rotate_right(tree, x)
	local p = x.parent
	local y = x.left

	if y.right then
		y.right.parent = x
	end
	x.left = y.right

	x.parent = y
	y.right = x

	y.parent = p
	if not p then
		tree.root = y
	elseif x == p.right then
		p.right = y
	else
		p.left = y
	end
end

local function transplant(tree, x, y)
	if not x.parent then
		tree.root = y
	elseif x == x.parent.left then
		x.parent.left = y
	else
		x.parent.right = y
	end
	if y then
		y.parent = x.parent
	end
end

local function fix_insert(tree, x)
	while x.parent.color == 1 do
		if x.parent == x.parent.parent.right then
			local u = x.parent.parent.left
			if u and u.color == 1 then
				u.color = 0
				x.parent.color = 0
				x.parent.parent.color = 1
				x = x.parent.parent
			else
				if x == x.parent.left then
					x = x.parent
					rotate_right(tree, x)
				end
				x.parent.color = 0
				x.parent.parent.color = 1
				rotate_left(tree, x.parent.parent)
			end
		else
			local u = x.parent.parent.right
			if u and u.color == 1 then
				u.color = 0
				x.parent.color = 0
				x.parent.parent.color = 1
				x = x.parent.parent
			else
				if x == x.parent.right then
					x = x.parent
					rotate_left(tree, x)
				end
				x.parent.color = 0
				x.parent.parent.color = 1
				rotate_right(tree, x.parent.parent)
			end
		end
		if x == tree.root then
			break
		end
	end
	tree.root.color = 0
end

local function fix_remove(tree, x, xp)  -- x may be nil (nil node), xp may be nil (parent of root node)
	while xp or x ~= tree.root and x.color == 0 do
		local p = xp or x.parent
		xp = nil
		if x == p.left then
			local s = p.right
			if s.color == 1 then
				s.color = 0
				p.color = 1
				rotate_left(tree, p)
				s = p.right
			end
			if (not s.left or s.left.color == 0) and (not s.right or s.right.color == 0) then
				s.color = 1
				x = p
			else
				if not s.right or s.right.color == 0 then
					s.left.color = 0
					s.color = 1
					rotate_right(tree, s)
					s = p.right
				end
				s.color = p.color
				p.color = 0
				if s.right then
					s.right.color = 0
				end
				rotate_left(tree, p)
				x = tree.root
			end
		else
			local s = p.left
			if s.color == 1 then
				s.color = 0
				p.color = 1
				rotate_right(tree, p)
				s = p.left
			end
			if (not s.left or s.left.color == 0) and (not s.right or s.right.color == 0) then
				s.color = 1
				x = p
			else
				if not s.left or s.left.color == 0 then
					s.right.color = 0
					s.color = 1
					rotate_left(tree, s)
					s = p.left
				end
				s.color = p.color
				p.color = 0
				if s.left then
					s.left.color = 0
				end
				rotate_right(tree, p)
				x = tree.root
			end
		end
	end
	if not x then
		return
	end
	x.color = 0
end

local function min(x)
	while x.left do
		x = x.left
	end
	return x
end

local function max(x)
	while x.right do
		x = x.right
	end
	return x
end

function Node:next()
	if self.right then
		return min(self.right)
	end

	local x, p = self, self.parent
	while p and x == p.right do
		x, p = p, p.parent
	end

	return p
end

function Node:prev()
	if self.left then
		return max(self.left)
	end

	local x, p = self, self.parent
	while p and x == p.left do
		x, p = p, p.parent
	end

	return p
end

function Node_mt:__tostring()
	local color = self.color == 1 and "🔴" or "⚫"
	return color .. " " .. tostring(self.key)
end

function Tree:find(key)
	local y
	local x = self.root
	while x and key ~= x.key do
		y = x
		if key < x.key then
			x = x.left
		else
			x = x.right
		end
	end
	return x, y
end

function Tree:findex(key, f)
	local y
	local x = self.root
	while x and key ~= f(x.key) do
		y = x
		if key < f(x.key) then
			x = x.left
		else
			x = x.right
		end
	end
	return x, y
end

function Tree:insert(key)
	local x, y = self:find(key)
	if x then
		return nil, "found"
	end

	self.size = self.size + 1

	x = {
		key = key,
		color = y and 1 or 0,
		parent = y,
		left = nil,
		right = nil,
	}
	setmetatable(x, Node_mt)

	if not y then
		self.root = x
		return x
	end

	if x.key < y.key then
		y.left = x
	else
		y.right = x
	end

	if y.parent then
		fix_insert(self, x)
	end

	return x
end

function Tree:remove(key)
	local z = self:find(key)
	if not z then
		return nil, "not found"
	end

	self.size = self.size - 1

	local x
	local color = z.color
	local zp = z.parent
	if not z.left and not z.right then
		transplant(self, z, nil)
	elseif not z.left then
		x = z.right
		transplant(self, z, z.right)
	elseif not z.right then
		x = z.left
		transplant(self, z, z.left)
	else
		local y = min(z.right)
		color = y.color
		x = y.right
		zp = y.parent

		if y.parent == z then
			zp = y
		else
			transplant(self, y, x)
			y.right = z.right
			y.right.parent = y
		end

		transplant(self, z, y)
		y.left = z.left
		y.left.parent = y
		y.color = z.color
	end

	if color == 0 then
		fix_remove(self, x, zp)
	end

	return z
end

local function check_subtree(t)
    if not t then
        return true, 1
	end

    if not t.parent and t.color == 1 then
        return false, 0
	end

	local black
    if t.color == 1 then
        black = 0
        if t.left and t.left.color == 1 or t.right and t.right.color == 1 then
            return false, -1
		end
    else
        black = 1
	end

    local r, black_right = check_subtree(t.right)
    local l, black_left = check_subtree(t.left)

    return r and l and black_right == black_left, black_right + black
end

function Tree:is_valid()
	return (check_subtree(self.root))
end

local function print_node(node, indent)
	if not node then
		return
	end

	indent = indent or 0

	print_node(node.left, indent + 1)
	print(("  "):rep(indent) .. tostring(node))
	print_node(node.right, indent + 1)
end

function Tree:print()
	return print_node(self.root, 0)
end

local function next_tree_node(tree, node)
	if node then
		node = node:next()
	else
		node = tree:min()
	end
	return node, node and node.key
end

function Tree:iter()
	return next_tree_node, self
end

function Tree:min()
	return self.root and min(self.root)
end

function Tree:max()
	return self.root and max(self.root)
end

local function new()
	return setmetatable({size = 0}, Tree_mt)
end

return {
	Tree = Tree,
	Node = Node,
	new = new
}