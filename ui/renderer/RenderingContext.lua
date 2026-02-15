require("table.clear")

---@class nya.RenderingContext
local RenderingContext = {}

---@enum RenderingContext.Operations
RenderingContext.Operations = {
	DRAW = 1,
	SET_COLOR = 2,
	SET_BLEND_MODE = 3,
	SET_STENCIL = 4,
	SET_CANVAS = 5,
	PUSH_STATE = 6,
	POP_STATE = 7
}

local OP = RenderingContext.Operations
local insert = table.insert

---@param node view.Node
---@param ctx (RenderingContext.Operations | any)[]
local function traverseTree(node, ctx)
	local has_state =
		node.color
		or node.blend_mode
		or node.stencil
		or node.canvas
		or node.draw

	if has_state then
		insert(ctx, OP.PUSH_STATE)
		if node.color then
			insert(ctx, OP.SET_COLOR)
			insert(ctx, node)
		end

		if node.blend_mode then
			insert(ctx, OP.SET_BLEND_MODE)
			insert(ctx, node.blend_mode.color)
			insert(ctx, node.blend_mode.alpha)
		end

		if node.stencil then
			insert(ctx, OP.SET_STENCIL)
			insert(ctx, node)
		end

		if node.canvas then
			insert(ctx, OP.SET_CANVAS)
			insert(ctx, node)
		end

		if node.draw then
			insert(ctx, OP.DRAW)
			insert(ctx, node)
		end
	end

	local c = node.children
	local l = #c
	for i = 1, l do
		traverseTree(c[i], ctx)
	end

	if has_state then
		insert(ctx, OP.POP_STATE)
	end
end

---@param root view.Node
---@return (RenderingContext.Operations | any)[]
function RenderingContext:build(root)
	local ctx = {}
	traverseTree(root, ctx)
	return ctx
end

return RenderingContext
