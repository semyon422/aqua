local class = require("class")
local get_blur_shader_code = require("ui.blur_shader_code")
require("table.clear")

---@class ui.Renderer
---@operator call: ui.Renderer
---@field context any[]
local Renderer = class()

local lg = love.graphics

local BLUR_SCALE = 0.5

local OP_DRAW = 1
local OP_STENCIL_START = 2
local OP_STENCIL_END = 3
local OP_CANVAS_START = 4
local OP_CANVAS_END = 5
local OP_BLUR_START = 6
local OP_BLUR_END = 7
local OP_BLUR_MASK = 8

local handlers = {}

local f, a, b, c
local function st()
	f(a, b, c)
end

local function stencil(func, _a, _b, _c)
	f = func
	a, b, c = _a, _b, _c
	lg.stencil(st, "replace", 1)
end

function Renderer:new()
	self.context = {}
	self.viewport_scale = 1

	local h_blur, v_blur = get_blur_shader_code(8)
	self.horizontal_blur = lg.newShader(h_blur)
	self.vertical_blur = lg.newShader(v_blur)
end

---@param node ui.Node
function Renderer:build(node)
	table.clear(self.context)
	self:buildRenderingContext(node)
end

local tex_size = { 0, 0 }
---@param scale number
function Renderer:setViewportScale(scale)
	self.viewport_scale = scale

	local ww, wh = lg.getDimensions()
	if not self.canvas or self.canvas:getWidth() ~= ww or self.canvas:getHeight() ~= wh then
		self.canvas = lg.newCanvas(ww, wh)
		self.horizontal_blur_canvas = lg.newCanvas(ww * BLUR_SCALE, wh * BLUR_SCALE)
		self.vertical_blur_canvas = lg.newCanvas(ww * BLUR_SCALE, wh * BLUR_SCALE)
	end

	tex_size[1] = ww
	tex_size[2] = wh
	self.horizontal_blur:send("tex_size", tex_size)
	self.vertical_blur:send("tex_size", tex_size)
end

function Renderer:draw()
	lg.setCanvas({ self.canvas, stencil = true })
	lg.clear()

	local ctx = self.context
	local i, n = 1, #ctx
	while i <= n do
		i = i + handlers[ctx[i]](self, ctx, i)
	end

	lg.setCanvas()
	lg.origin()
	lg.setColor(1, 1, 1)
	lg.draw(self.canvas)
end

---@param node ui.Node
function Renderer:buildRenderingContext(node)
	local ctx = self.context
	local n = #ctx + 1

	if node.draw_to_canvas then
		ctx[n] = OP_CANVAS_START
		ctx[n + 1] = node
		local tf = node.transform:inverse()
		tf:scale(self.viewport_scale, self.viewport_scale)
		ctx[n + 2] = tf
		n = n + 3
	end

	if node.stencil_mask then
		ctx[n] = OP_STENCIL_START
		ctx[n + 1] = node
		n = n + 2
	end

	if node.is_blur_layer then
		ctx[n] = OP_BLUR_START
		ctx[n + 1] = node
		n = n + 2
	end

	if node.blur_mask then
		ctx[n] = OP_BLUR_MASK
		ctx[n + 1] = node
		n = n + 2
	end

	if node.draw then
		ctx[n] = OP_DRAW
		ctx[n + 1] = node
		n = n + 2
	end

	for _, child in ipairs(node.children) do
		if (child.alpha * child.color[4] > 0) and not child.is_disabled then
			self:buildRenderingContext(child)
		end
	end

	n = #ctx + 1

	if node.is_blur_layer then
		ctx[n] = OP_BLUR_END
		n = n + 1
	end

	if node.stencil_mask then
		ctx[n] = OP_STENCIL_END
		n = n + 1
	end

	if node.draw_to_canvas then
		ctx[n] = OP_CANVAS_END
		ctx[n + 1] = node
		n = n + 2
	end
end

---@param renderer ui.Renderer
---@param context any[]
---@param i integer
handlers[OP_DRAW] = function(renderer, context, i)
	local node = context[i + 1]
	local color = node.color
	lg.setColor(color[1], color[2], color[3], color[4] * node.alpha)
	lg.push()
	lg.applyTransform(node.transform)
	node:draw()
	lg.pop()
	return 2
end

---@param renderer ui.Renderer
---@param context any[]
---@param i integer
handlers[OP_STENCIL_START] = function(renderer, context, i)
	local node = context[i + 1]
	lg.push()
	lg.applyTransform(node.transform)
	stencil(node.stencil_mask, node)
	lg.pop()
	lg.setStencilTest("greater", 0)
	return 2
end

---@param renderer ui.Renderer
---@param context any[]
---@param i integer
handlers[OP_STENCIL_END] = function(renderer, context, i)
	local node = context[i + 1]
	lg.setStencilTest()
	return 1
end

---@param renderer ui.Renderer
---@param context any[]
---@param i integer
handlers[OP_CANVAS_START] = function(renderer, context, i)
	local node = context[i + 1]
	local tf_inverse = context[i + 2]

	local w = math.ceil(node.width * renderer.viewport_scale)
	local h = math.ceil(node.height * renderer.viewport_scale)

	if not node.canvas or
		node.canvas:getWidth() ~= w or
		node.canvas:getHeight() ~= h
	then
		node.canvas = lg.newCanvas(w, h)
	end

	lg.push("all")
	lg.setCanvas({ node.canvas, stencil = true })
	lg.setBlendMode("alpha", "alphamultiply")
	lg.applyTransform(tf_inverse)
	lg.clear()
	return 3
end

---@param renderer ui.Renderer
---@param context any[]
---@param i integer
handlers[OP_CANVAS_END] = function(renderer, context, i)
	local node = context[i + 1]
	local canvas = lg.getCanvas()
	lg.pop()
	local c = node.color
	lg.setColor(c[1] * node.alpha, c[2] * node.alpha, c[3] * node.alpha, c[4] * node.alpha)
	lg.applyTransform(node.transform)
	lg.scale(1 / renderer.viewport_scale, 1 / renderer.viewport_scale)
	lg.setBlendMode("alpha", "premultiplied")
	lg.draw(canvas)
	lg.setBlendMode("alpha")
	return 2
end

local function blur_mask_stencil(renderer, context, i)
	lg.push()
	while context[i] ~= OP_BLUR_END do
		if context[i] == OP_BLUR_MASK then
			local node = context[i + 1]
			lg.push()
			lg.applyTransform(node.transform)
			node:blur_mask()
			lg.pop()
		end
		i = i + 1
	end
	lg.pop()
end

---@param renderer ui.Renderer
---@param context any[]
---@param i integer
handlers[OP_BLUR_START] = function(renderer, context, i)
	lg.push("all")
	lg.origin()
	lg.setColor(1, 1, 1)
	lg.setCanvas(renderer.horizontal_blur_canvas)
	lg.setShader(renderer.horizontal_blur)
	lg.scale(BLUR_SCALE)
	lg.draw(renderer.canvas)
	lg.pop()

	lg.push("all")
	lg.origin()
	lg.setColor(1, 1, 1)
	lg.setCanvas(renderer.vertical_blur_canvas)
	lg.setShader(renderer.vertical_blur)
	lg.draw(renderer.horizontal_blur_canvas)
	lg.pop()

	lg.push()
	stencil(blur_mask_stencil, renderer, context, i)
	lg.setStencilTest("greater", 0)
	lg.origin()
	lg.setColor(1, 1, 1)
	lg.scale(1 / BLUR_SCALE)
	lg.draw(renderer.vertical_blur_canvas)
	lg.setStencilTest()
	lg.pop()
	return 2
end

---@param renderer ui.Renderer
---@param context any[]
---@param i integer
handlers[OP_BLUR_END] = function(renderer, context, i)
	return 1
end

---@param renderer ui.Renderer
---@param context any[]
---@param i integer
handlers[OP_BLUR_MASK] = function(renderer, context, i)
	return 2
end

return Renderer
