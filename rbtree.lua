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

local function fix_remove(tree, x)
	while x ~= tree.root and x.color == 0 do
		if x == x.parent.left then
			local s = x.parent.right
			if s.color == 1 then
				s.color = 0
				x.parent.color = 1
				rotate_left(tree, x.parent)
				s = x.parent.right
			end
			if (not s.left or s.left.color == 0) and (not s.right or s.right.color == 0) then
				s.color = 1
				x = x.parent
			else
				if s.right.color == 0 then
					s.left.color = 0
					s.color = 1
					rotate_right(tree, s)
					s = x.parent.right
				end
				s.color = x.parent.color
				x.parent.color = 0
				s.right.color = 0
				rotate_left(tree, x.parent)
				x = tree.root
			end
		else
			local s = x.parent.left
			if s.color == 1 then
				s.color = 0
				x.parent.color = 1
				rotate_right(tree, x.parent)
				s = x.parent.left
			end
			if (not s.left or s.left.color == 0) and (not s.right or s.right.color == 0) then
				s.color = 1
				x = x.parent
			else
				if s.left.color == 0 then
					s.right.color = 0
					s.color = 1
					rotate_left(tree, s)
					s = x.parent.left
				end
				s.color = x.parent.color
				x.parent.color = 0
				s.left.color = 0
				rotate_right(tree, x.parent)
				x = tree.root
			end
		end
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
	if not z.left then
		x = z.right
		transplant(self, z, z.right)
	elseif not z.right then
		x = z.left
		transplant(self, z, z.left)
	else
		local y = min(z.right)
		color = y.color
		x = y.right
		if y.parent == z then
			if x then
				x.parent = y
			end
		else
			transplant(self, y, y.right)
			y.right = z.right
			y.right.parent = y
		end

		transplant(self, z, y)
		y.left = z.left
		y.left.parent = y
		y.color = z.color
	end

	if x and color == 0 then
		fix_remove(self, x)
	end

	return z
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
		return node:next()
	end
	return tree:min()
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
