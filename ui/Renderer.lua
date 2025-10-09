local class = require("class")
require("table.clear")

---@class ui.Renderer
---@operator call: ui.Renderer
---@field context any[]
local Renderer = class()

local Ops = {
	Draw = 1,
	StencilStart = 2,
	StencilEnd = 3,
	CanvasStart = 4,
	CanvasEnd = 5,
	BlurStart = 6,
	BlurEnd = 7,
}

local handlers = {}

function Renderer:new()
	self.context = {}
	self.viewport_scale = 1
end

---@param node ui.Node
function Renderer:build(node)
	table.clear(self.context)
	self:buildRenderingContext(node)
end

---@param scale number
function Renderer:setViewportScale(scale)
	self.viewport_scale = scale
end

function Renderer:draw()
	local ctx = self.context
	local i, n = 1, #ctx
	while i <= n do
		i = i + handlers[ctx[i]](self, ctx, i)
	end
end

---@param node ui.Node
function Renderer:buildRenderingContext(node)
	if node.draw_to_canvas then
		table.insert(self.context, Ops.CanvasStart)
		table.insert(self.context, node)
		table.insert(self.context, node.transform:inverse())
	end

	if node.stencil_mask then
		table.insert(self.context, Ops.StencilStart)
		table.insert(self.context, node)
	end

	if node.draw then
		table.insert(self.context, Ops.Draw)
		table.insert(self.context, node)
	end


	for _, child in ipairs(node.children) do
		self:buildRenderingContext(child)
	end

	if node.stencil_mask then
		table.insert(self.context, Ops.StencilEnd)
	end

	if node.draw_to_canvas then
		table.insert(self.context, Ops.CanvasEnd)
		table.insert(self.context, node)
	end
end

handlers[Ops.Draw] = function(renderer, context, i)
	local node = context[i + 1]
	local c = node.color
	love.graphics.setColor(c[1], c[2], c[3], c[4] * node.alpha)
	love.graphics.push()
	love.graphics.applyTransform(node.transform)
	node:draw()
	love.graphics.pop()
	return 2
end

handlers[Ops.StencilStart] = function(renderer, context, i)
	local node = context[i + 1]
	love.graphics.push()
	love.graphics.applyTransform(node.transform)
	love.graphics.stencil(node.stencil_mask, "replace", 1)
	love.graphics.pop()
	love.graphics.setStencilTest("greater", 0)
	return 2
end

handlers[Ops.StencilEnd] = function(renderer, context, i)
	local node = context[i + 1]
	love.graphics.setStencilTest()
	return 1
end

handlers[Ops.CanvasStart] = function(renderer, context, i)
	local node = context[i + 1]
	local tf_inverse = context[i + 2]

	local w, h = node.width * renderer.viewport_scale, node.height * renderer.viewport_scale
	if not node.canvas or
		node.canvas:getWidth() ~= w or
		node.canvas:getHeight() ~= h
	then
		node.canvas = love.graphics.newCanvas(w, h)
	end

	love.graphics.push("all")
	love.graphics.setCanvas({ node.canvas, stencil = true })
	love.graphics.setBlendMode("alpha", "alphamultiply")
	love.graphics.applyTransform(tf_inverse)
	love.graphics.clear()
	return 3
end

handlers[Ops.CanvasEnd] = function(renderer, context, i)
	local node = context[i + 1]
	local canvas = love.graphics.getCanvas()
	love.graphics.pop()
	local c = node.color
	love.graphics.setColor(c[1] * node.alpha, c[2] * node.alpha, c[3] * node.alpha, c[4] * node.alpha)
	love.graphics.applyTransform(node.transform)
	love.graphics.setBlendMode("alpha", "premultiplied")
	love.graphics.draw(canvas)
	love.graphics.setBlendMode("alpha")
	return 2
end

handlers[Ops.BlurStart] = function(renderer, context, i)
	return 2
end

handlers[Ops.BlurEnd] = function(renderer, context, i)
	return 1
end

return Renderer
