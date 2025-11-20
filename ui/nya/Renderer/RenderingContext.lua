local class = require("class")
local OP = require("ui.nya.Renderer.ops")

---@class nya.RenderingContext
---@operator call: nya.RenderingContext
local RenderingContext = class()

function RenderingContext:new()
	self.viewport_scale = 1
	self.ctx = {}
	self.ctx_size = 1
end

---@param root nya.Node
function RenderingContext:build(root)
	self.ctx_size = 1
	self:extractOps(root)
	self.ctx_size = self.ctx_size - 1
end

---@param tf love.Transform
---@return number sx
---@return number sy
local function getTransformScale(tf)
	local e1_1, e1_2, _, _, e2_1, e2_2, _, _, e3_1, e3_2 = tf:getMatrix()
	local scale_x = math.sqrt(e1_1 * e1_1 + e2_1 * e2_1 + e3_1 * e3_1)
	local scale_y = math.sqrt(e1_2 * e1_2 + e2_2 * e2_2 + e3_2 * e3_2)
	return scale_x, scale_y
end

---@param node nya.Node
function RenderingContext:extractOps(node)
	local ctx = self.ctx
	local ctx_size = self.ctx_size
	local style = node.style

	if style and style.stencil_mask then
		ctx[ctx_size] = OP.STENCIL_START
		ctx[ctx_size + 1] = node
		ctx_size = ctx_size + 2
	end

	if style then
		ctx[ctx_size] = OP.UPDATE_STYLE
		ctx[ctx_size + 1] = style
		ctx_size = ctx_size + 2

		if style.shadow then
			ctx[ctx_size] = OP.DRAW_STYLE_SHADOW
			ctx[ctx_size + 1] = style
			ctx[ctx_size + 2] = node.transform
			ctx_size = ctx_size + 3
		end

		if style.backdrop then
			local sx, sy = getTransformScale(node.transform)
			ctx[ctx_size] = OP.DRAW_STYLE_BACKDROP
			ctx[ctx_size + 1] = node.style
			ctx[ctx_size + 2] = node
			ctx[ctx_size + 3] = sx
			ctx[ctx_size + 4] = sy
			ctx_size = ctx_size + 5
		end

		if style.content_cache then
			ctx[ctx_size] = OP.STYLE_CONTENT_CACHE_BEGIN
			ctx[ctx_size + 1] = node
			ctx_size = ctx_size + 2
		end

		if style.content then
			if node.draw then
				ctx[ctx_size] = OP.DRAW_STYLE_CONTENT_SELF_DRAW
				ctx[ctx_size + 1] = style
				ctx[ctx_size + 2] = node
				ctx[ctx_size + 3] = node.transform
				ctx_size = ctx_size + 4
			else
				ctx[ctx_size] = OP.DRAW_STYLE_CONTENT
				ctx[ctx_size + 1] = node.style
				ctx[ctx_size + 2] = node.transform
				ctx_size = ctx_size + 3
			end
		end
	elseif node.draw then
		ctx[ctx_size] = OP.DRAW
		ctx[ctx_size + 1] = node
		ctx_size = ctx_size + 2
	end

	self.ctx_size = ctx_size

	for _, child in ipairs(node.children) do
		self:extractOps(child)
	end

	ctx_size = self.ctx_size

	if style then
		if style.content_cache then
			ctx[ctx_size] = OP.STYLE_CONTENT_CACHE_END
			ctx_size = ctx_size + 1

			ctx[ctx_size] = OP.DRAW_STYLE_CONTENT_CACHE
			ctx[ctx_size + 1] = node.style
			ctx[ctx_size + 2] = node.transform
			ctx_size = ctx_size + 3
		end

		if style.stencil_mask then
			ctx[ctx_size] = OP.STENCIL_END
			ctx_size = ctx_size + 1
		end
	end

	self.ctx_size = ctx_size
end

return RenderingContext
