-- red-black tree

local Tree = {}
local Tree_mt = {__index = Tree}

local Node = {}
local Node_mt = {__index = Node}

local function rotate_left(x)
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
		x.tree.root = y
	elseif x == p.left then
		p.left = y
	else
		p.right = y
	end
end

local function rotate_right(x)
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
		x.tree.root = y
	elseif x == p.right then
		p.right = y
	else
		p.left = y
	end
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

local function transplant(x, y)
	if not x.parent then
		x.tree.root = y
	elseif x == x.parent.left then
		x.parent.left = y
	else
		x.parent.right = y
	end
	if y then
		y.parent = x.parent
	end
end

local function fix_insert(x)
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
					rotate_right(x)
				end
				x.parent.color = 0
				x.parent.parent.color = 1
				rotate_left(x.parent.parent)
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
					rotate_left(x)
				end
				x.parent.color = 0
				x.parent.parent.color = 1
				rotate_right(x.parent.parent)
			end
		end
		if x == x.tree.root then
			break
		end
	end
	x.tree.root.color = 0
end

local function fix_remove(x)
	while x ~= x.tree.root and x.color == 0 do
		if x == x.parent.left then
			local s = x.parent.right
			if s.color == 1 then
				s.color = 0
				x.parent.color = 1
				rotate_left(x.parent)
				s = x.parent.right
			end
			if (not s.left or s.left.color == 0) and (not s.right or s.right.color == 0) then
				s.color = 1
				x = x.parent
			else
				if s.right.color == 0 then
					s.left.color = 0
					s.color = 1
					rotate_right(s)
					s = x.parent.right
				end
				s.color = x.parent.color
				x.parent.color = 0
				s.right.color = 0
				rotate_left(x.parent)
				x = x.tree.root
			end
		else
			local s = x.parent.left
			if s.color == 1 then
				s.color = 0
				x.parent.color = 1
				rotate_right(x.parent)
				s = x.parent.left
			end
			if (not s.left or s.left.color == 0) and (not s.right or s.right.color == 0) then
				s.color = 1
				x = x.parent
			else
				if s.left.color == 0 then
					s.right.color = 0
					s.color = 1
					rotate_left(s)
					s = x.parent.left
				end
				s.color = x.parent.color
				x.parent.color = 0
				s.left.color = 0
				rotate_right(x.parent)
				x = x.tree.root
			end
		end
	end
	x.color = 0
end

local function next_node(self, x)
	if not x then
		if not self.root then
			return
		end
		return min(self.root)
	elseif x.right then
		return min(x.right)
	end

	local p = x.parent
	while p and x == p.right do
		x = p
		p = p.parent
	end

	return p
end

local function prev_node(self, x)
	if not x then
		return max(self.root)
	elseif x.left then
		return max(x.left)
	end

	local p = x.parent
	while p and x == p.left do
		x = p
		p = p.parent
	end

	return p
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

function Node:next()
	return next_node(self.tree, self)
end

function Node:prev()
	return prev_node(self.tree, self)
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

	x = {
		key = key,
		tree = self,
		color = 1,
	}
	setmetatable(x, Node_mt)

	x.parent = y
	if not y then
		self.root = x
	elseif x.key < y.key then
		y.left = x
	else
		y.right = x
	end

	if not x.parent then
		x.color = 0
		return x
	end

	if not x.parent.parent then
		return x
	end

	fix_insert(x)

	return x
end

function Tree:remove(key)
	local z = self:find(key)
	if not z then
		return nil, "not found"
	end

	local x
	local color = z.color
	if not z.left then
		x = z.right
		transplant(z, z.right)
	elseif not z.right then
		x = z.left
		transplant(z, z.left)
	else
		local y = min(z.right)
		color = y.color
		x = y.right
		if y.parent == z then
			if x then
				x.parent = y
			end
		else
			transplant(y, y.right)
			y.right = z.right
			y.right.parent = y
		end

		transplant(z, y)
		y.left = z.left
		y.left.parent = y
		y.color = z.color
	end

	if x and color == 0 then
		fix_remove(x)
	end

	return z
end

function Tree:print()
	return print_node(self.root, 0)
end

function Tree:iter()
	return next_node, self
end

function Tree:min()
	return self.root and min(self.root)
end

function Tree:max()
	return self.root and max(self.root)
end

local function new()
	return setmetatable({}, Tree_mt)
end

return {
	Tree = Tree,
	Node = Node,
	new = new
}
