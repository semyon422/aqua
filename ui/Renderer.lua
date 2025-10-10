local class = require("class")
local get_blur_shader_code = require("ui.blur_shader_code")
require("table.clear")

---@class ui.Renderer
---@operator call: ui.Renderer
---@field context any[]
local Renderer = class()

local blur_scale = 0.5

local Ops = {
	Draw = 1,
	StencilStart = 2,
	StencilEnd = 3,
	CanvasStart = 4,
	CanvasEnd = 5,
	BlurStart = 6,
	BlurEnd = 7,
	BlurMask = 8
}

local handlers = {}

local f, a, b, c, d, e
local function st()
	f(a, b, c, d, e)
end

local function stencil(func, _a, _b, _c, _d, _e)
	f = func
	a, b, c, d, e = _a, _b, _c, _d, _e
	love.graphics.stencil(st, "replace", 1)
end

function Renderer:new()
	self.context = {}
	self.viewport_scale = 1

	local h_blur, v_blur = get_blur_shader_code(8)
	self.horizontal_blur = love.graphics.newShader(h_blur)
	self.vertical_blur = love.graphics.newShader(v_blur)
end

---@param node ui.Node
function Renderer:build(node)
	table.clear(self.context)
	self:buildRenderingContext(node)
end

---@param scale number
function Renderer:setViewportScale(scale)
	self.viewport_scale = scale

	local ww, wh = love.graphics.getDimensions()
	if not self.canvas or self.canvas:getWidth() ~= ww or self.canvas:getHeight() ~= wh then
		self.canvas = love.graphics.newCanvas(ww, wh)
		self.horizontal_blur_canvas = love.graphics.newCanvas(ww * blur_scale, wh * blur_scale)
		self.vertical_blur_canvas = love.graphics.newCanvas(ww * blur_scale, wh * blur_scale)
	end

	local tex_size = { ww, wh }
	self.horizontal_blur:send("tex_size", tex_size)
	self.vertical_blur:send("tex_size", tex_size)
end

function Renderer:draw()
	love.graphics.setCanvas({ self.canvas, stencil = true })
	love.graphics.clear()
	local ctx = self.context
	local i, n = 1, #ctx
	while i <= n do
		i = i + handlers[ctx[i]](self, ctx, i)
	end
	love.graphics.setCanvas()
	love.graphics.origin()
	love.graphics.setColor(1, 1, 1)
	love.graphics.draw(self.canvas)
end

---@param node ui.Node
function Renderer:buildRenderingContext(node)
	if node.draw_to_canvas then
		table.insert(self.context, Ops.CanvasStart)
		table.insert(self.context, node)

		local tf = node.transform:inverse()
		tf:scale(self.viewport_scale, self.viewport_scale)
		table.insert(self.context, tf)
	end

	if node.stencil_mask then
		table.insert(self.context, Ops.StencilStart)
		table.insert(self.context, node)
	end

	if node.is_blur_layer then
		table.insert(self.context, Ops.BlurStart)
		table.insert(self.context, node)
	end

	if node.blur_mask then
		table.insert(self.context, Ops.BlurMask)
		table.insert(self.context, node)
	end

	if node.draw then
		table.insert(self.context, Ops.Draw)
		table.insert(self.context, node)
	end

	for _, child in ipairs(node.children) do
		if (child.alpha * child.color[4] > 0) and not child.is_disabled then
			self:buildRenderingContext(child)
		end
	end

	if node.is_blur_layer then
		table.insert(self.context, Ops.BlurEnd)
	end

	if node.stencil_mask then
		table.insert(self.context, Ops.StencilEnd)
	end

	if node.draw_to_canvas then
		table.insert(self.context, Ops.CanvasEnd)
		table.insert(self.context, node)
	end
end

---@param renderer ui.Renderer
---@param context any[]
---@param i integer
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

---@param renderer ui.Renderer
---@param context any[]
---@param i integer
handlers[Ops.StencilStart] = function(renderer, context, i)
	local node = context[i + 1]
	love.graphics.push()
	love.graphics.applyTransform(node.transform)
	stencil(node.stencil_mask, node)
	love.graphics.pop()
	love.graphics.setStencilTest("greater", 0)
	return 2
end

---@param renderer ui.Renderer
---@param context any[]
---@param i integer
handlers[Ops.StencilEnd] = function(renderer, context, i)
	local node = context[i + 1]
	love.graphics.setStencilTest()
	return 1
end

---@param renderer ui.Renderer
---@param context any[]
---@param i integer
handlers[Ops.CanvasStart] = function(renderer, context, i)
	local node = context[i + 1]
	local tf_inverse = context[i + 2]

	local w = math.ceil(node.width * renderer.viewport_scale)
	local h = math.ceil(node.height * renderer.viewport_scale)

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

---@param renderer ui.Renderer
---@param context any[]
---@param i integer
handlers[Ops.CanvasEnd] = function(renderer, context, i)
	local node = context[i + 1]
	local canvas = love.graphics.getCanvas()
	love.graphics.pop()
	local c = node.color
	love.graphics.setColor(c[1] * node.alpha, c[2] * node.alpha, c[3] * node.alpha, c[4] * node.alpha)
	love.graphics.applyTransform(node.transform)
	love.graphics.scale(1 / renderer.viewport_scale, 1 / renderer.viewport_scale)
	love.graphics.setBlendMode("alpha", "premultiplied")
	love.graphics.draw(canvas)
	love.graphics.setBlendMode("alpha")
	return 2
end

local blur_mask_stencil = function(renderer, context, i)
	love.graphics.push()
	while context[i] ~= Ops.BlurEnd do
		if context[i] == Ops.BlurMask then
			local node = context[i + 1]
			love.graphics.push()
			love.graphics.applyTransform(node.transform)
			node:blur_mask()
			love.graphics.pop()
		end
		i = i + 1
	end
	love.graphics.pop()
end

---@param renderer ui.Renderer
---@param context any[]
---@param i integer
handlers[Ops.BlurStart] = function(renderer, context, i)
	love.graphics.push("all")
	love.graphics.origin()
	love.graphics.setColor(1, 1, 1)
	love.graphics.setCanvas(renderer.horizontal_blur_canvas)
	love.graphics.setShader(renderer.horizontal_blur)
	love.graphics.scale(blur_scale)
	love.graphics.draw(renderer.canvas)
	love.graphics.pop()

	love.graphics.push("all")
	love.graphics.origin()
	love.graphics.setColor(1, 1, 1)
	love.graphics.setCanvas(renderer.vertical_blur_canvas)
	love.graphics.setShader(renderer.vertical_blur)
	love.graphics.draw(renderer.horizontal_blur_canvas)
	love.graphics.pop()

	love.graphics.push()
	stencil(blur_mask_stencil, renderer, context, i)
	love.graphics.setStencilTest("greater", 0)
	love.graphics.origin()
	love.graphics.setColor(1, 1, 1)
	love.graphics.scale(1 / blur_scale)
	love.graphics.draw(renderer.vertical_blur_canvas)
	love.graphics.setStencilTest()
	love.graphics.pop()
	return 2
end

---@param renderer ui.Renderer
---@param context any[]
---@param i integer
handlers[Ops.BlurEnd] = function(renderer, context, i)
	return 1
end

---@param renderer ui.Renderer
---@param context any[]
---@param i integer
handlers[Ops.BlurMask] = function(renderer, context, i)
	return 2
end

return Renderer
