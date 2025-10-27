local class = require("class")
local get_blur_shader_code = require("ui.blur_shader_code")
local OP = require("ui.Renderer.ops")
local RenderingContext = require("ui.Renderer.RenderingContext")

---@class ui.Renderer
---@operator call: ui.Renderer
local Renderer = class()

local lg = love.graphics

local BLUR_SCALE = 0.5
local BLUR_RADIUS = 8

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
	self.context = RenderingContext()
	self.viewport_scale = 1

	local h_blur, v_blur = get_blur_shader_code(BLUR_RADIUS)
	self.horizontal_blur = lg.newShader(h_blur)
	self.vertical_blur = lg.newShader(v_blur)

	self.pixel = love.graphics.newCanvas(1, 1)
	lg.setCanvas(self.pixel)
	lg.clear(0, 0, 0, 0)
	lg.setCanvas()
end

---@param root ui.Node
function Renderer:build(root)
	self.context:build(root)
end

local tex_size = { 0, 0 }
---@param scale number
function Renderer:setViewportScale(scale)
	self.viewport_scale = scale
	self.context.viewport_scale = scale

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

	local ctx = self.context.ctx
	local i, n = 1, self.context.ctx_size
	while i <= n do
		i = i + handlers[ctx[i]](self, ctx, i)
	end

	lg.setCanvas()
	lg.origin()
	lg.setColor(1, 1, 1)
	lg.draw(self.canvas)
end

---@param renderer ui.Renderer
---@param context any[]
---@param i integer
handlers[OP.DRAW] = function(renderer, context, i)
	local node = context[i + 1]
	lg.push()
	lg.applyTransform(node.transform)
	node:draw()
	lg.pop()
	return 2
end

---@param renderer ui.Renderer
---@param context any[]
---@param i integer
handlers[OP.DRAW_WITH_STYLE] = function(renderer, context, i)
	local node = context[i + 1]
	local style = node.style
	lg.push()
	lg.applyTransform(node.transform)
	lg.setShader(style.shader)
	style.width = node.width
	style.height = node.height
	style:passUniforms()
	node:draw()
	lg.setShader()
	lg.pop()
	return 2
end

---@param renderer ui.Renderer
---@param context any[]
---@param i integer
handlers[OP.DRAW_WITH_STYLE_NO_TEXTURE] = function(renderer, context, i)
	local node = context[i + 1]
	local style = node.style
	lg.push()
	lg.applyTransform(node.transform)
	lg.setShader(node.style.shader)
	style.width = node.width
	style.height = node.height
	node.style:passUniforms()
	lg.draw(renderer.pixel, 0, 0, 0, node.width, node.height)
	lg.setShader()
	lg.pop()
	return 2
end

---@param renderer ui.Renderer
---@param context any[]
---@param i integer
handlers[OP.STENCIL_START] = function(renderer, context, i)
	local node = context[i + 1]
	lg.push()
	lg.applyTransform(node.transform)
	stencil(node.style.mask, node)
	lg.pop()
	lg.setStencilTest("greater", 0)
	return 2
end

---@param renderer ui.Renderer
---@param context any[]
---@param i integer
handlers[OP.STENCIL_END] = function(renderer, context, i)
	local node = context[i + 1]
	lg.setStencilTest()
	return 1
end

---@param renderer ui.Renderer
---@param context any[]
---@param i integer
handlers[OP.CANVAS_START] = function(renderer, context, i)
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
handlers[OP.CANVAS_END] = function(renderer, context, i)
	local node = context[i + 1]
	local canvas = lg.getCanvas()
	lg.pop()
	--local c = node.color
	--lg.setColor(c[1] * node.alpha, c[2] * node.alpha, c[3] * node.alpha, c[4] * node.alpha)
	lg.applyTransform(node.transform)
	lg.scale(1 / renderer.viewport_scale, 1 / renderer.viewport_scale)
	lg.setBlendMode("alpha", "premultiplied")
	lg.draw(canvas)
	lg.setBlendMode("alpha")
	return 2
end

local function blur_mask_stencil(renderer, context, i)
	lg.push()
	while context[i] ~= OP.BLUR_END do
		if context[i] == OP.BLUR_MASK then
			local node = context[i + 1]
			local style = node.style
			lg.push()
			lg.applyTransform(node.transform)
			if type(style.backdrop_blur) == "function" then
				node.style.backdrop_blur(node)
			else
				lg.rectangle("fill", 0, 0, node.width, node.height)
			end
			lg.pop()
		end
		i = i + 1
	end
	lg.pop()
end

---@param renderer ui.Renderer
---@param context any[]
---@param i integer
handlers[OP.BLUR_START] = function(renderer, context, i)
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
handlers[OP.BLUR_END] = function(renderer, context, i)
	return 1
end

---@param renderer ui.Renderer
---@param context any[]
---@param i integer
handlers[OP.BLUR_MASK] = function(renderer, context, i)
	return 2
end

return Renderer
