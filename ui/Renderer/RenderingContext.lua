local class = require("class")
local OP = require("ui.Renderer.ops")

---@class ui.RenderingContext
---@operator call: ui.RenderingContext
local RenderingContext = class()

function RenderingContext:new()
	self.viewport_scale = 1
	self.ctx = {}
	self.ctx_size = 1
end

---@param root ui.Node
function RenderingContext:build(root)
	self.ctx_size = 1
	self:extractOps(root)
	self.ctx_size = self.ctx_size - 1
end

local pre_draw_order = {
	"is_canvas",
	"mask",
	"is_backdrop",
	"backdrop_blur",
	"color",
	--"alpha"
}

local post_draw_order = {
	"is_backdrop",
	"mask",
	"is_canvas",
}

---@type {[string]: fun(self: ui.RenderingContext, ctx: any[], n: integer, node: ui.Node): integer}
local pre_draw = {
	is_canvas = function(self, ctx, n, node)
		ctx[n] = OP.CANVAS_START
		ctx[n + 1] = node
		local tf = node.transform:inverse()
		tf:scale(self.viewport_scale, self.viewport_scale)
		ctx[n + 2] = tf
		return 3
	end,
	mask = function(_, ctx, n, node)
		ctx[n] = OP.STENCIL_START
		ctx[n + 1] = node
		return 2
	end,
	is_backdrop = function(_, ctx, n, node)
		ctx[n] = OP.BLUR_START
		ctx[n + 1] = node
		return 2
	end,
	backdrop_blur = function(_, ctx, n, node)
		ctx[n] = OP.BLUR_MASK
		ctx[n + 1] = node
		return 2
	end,
}

---@type {[string]: fun(self: ui.RenderingContext, ctx: any[], n: integer, node: ui.Node): integer}
local post_draw = {
	is_canvas = function(_, ctx, n, node)
		ctx[n] = OP.CANVAS_END
		ctx[n + 1] = node
		return 2
	end,
	mask = function(_, ctx, n, _)
		ctx[n] = OP.STENCIL_END
		return 1
	end,
	is_backdrop = function(_, ctx, n, _)
		ctx[n] = OP.BLUR_END
		return 1
	end
}

---@param node ui.Node
function RenderingContext:extractOps(node)
	local ctx = self.ctx
	local ctx_size = self.ctx_size
	local style = node.style

	if style then
		for i = 1, #pre_draw_order do
			local v = pre_draw_order[i]
			if style[v] then
				ctx_size = ctx_size + pre_draw[v](self, ctx, ctx_size, node)
			end
		end

		if style.shader then
			ctx[ctx_size] = node.draw and OP.DRAW_WITH_STYLE or OP.DRAW_WITH_STYLE_NO_TEXTURE
			ctx[ctx_size + 1] = node
			ctx_size = ctx_size + 2
		end
	else
		if node.draw then
			ctx[ctx_size] = OP.DRAW
			ctx[ctx_size + 1] = node
			ctx_size = ctx_size + 2
		end
	end

	self.ctx_size = ctx_size

	for _, child in ipairs(node.children) do
		self:extractOps(child)
	end

	ctx_size = self.ctx_size

	if style then
		for i = 1, #post_draw_order do
			local v = post_draw_order[i]
			if style[v] then
				ctx_size = ctx_size + post_draw[v](self, ctx, ctx_size, node)
			end
		end
	end

	self.ctx_size = ctx_size
end

return RenderingContext
