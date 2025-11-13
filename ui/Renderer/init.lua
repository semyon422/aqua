local class = require("class")
local OP = require("ui.Renderer.ops")
local RenderingContext = require("ui.Renderer.RenderingContext")
local RegionEffect = require("ui.Renderer.RegionEffect")
local ShaderBuilder = require("ui.Renderer.ShaderBuilder")

---@class ui.Renderer
---@operator call: ui.Renderer
local Renderer = class()

local lg = love.graphics
local handlers = {}

function Renderer:new()
	self.context = RenderingContext()
	self.viewport_scale = 1

	self.pixel = love.graphics.newCanvas(1, 1)
end

---@param root ui.Node
function Renderer:build(root)
	self.context:build(root)
end

---@param scale number
function Renderer:setViewportScale(scale)
	self.viewport_scale = scale
	self.context.viewport_scale = scale

	local ww, wh = lg.getDimensions()
	if not self.canvas or self.canvas:getWidth() ~= ww or self.canvas:getHeight() ~= wh then
		self.canvas = lg.newCanvas(ww, wh)
		self.region_effect = RegionEffect(ww, wh)
	end
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

handlers[OP.UPDATE_STYLE] = function(renderer, context, i)
	local style = context[i + 1] ---@type ui.Style
	style:updateMaterials()
	return 2
end

---@param renderer ui.Renderer
---@param context any[]
---@param i integer
handlers[OP.DRAW_STYLE_BACKDROP] = function(renderer, context, i)
	local style = context[i + 1] ---@type ui.Style
	local tf = context[i + 2] ---@type love.Transform
	local i_tf = context[i + 3] ---@type love.Transform
	local tf_scale_x = context[i + 4] ---@type number
	local tf_scale_y = context[i + 5] ---@type number
	local region_effect = renderer.region_effect ---@type ui.RegionEffect
	local main_canvas = renderer.canvas ---@type love.Canvas
	local backdrop = style.backdrop ---@type ui.Style.Backdrop

	local visual_width, visual_height = style.width * tf_scale_x, style.height * tf_scale_y
	local ww, wh = love.graphics.getDimensions()
	style:setBackdropUvScale(visual_width / ww, visual_height / wh)

	lg.push()
	lg.scale(tf_scale_x, tf_scale_y)
	lg.applyTransform(i_tf)
	region_effect:setCaptureRegion(
		main_canvas,
		visual_width,
		visual_height,
		style.padding
	)
	region_effect:captureRegion()
	lg.pop()

	if backdrop.blur then
		region_effect:applyBlur(backdrop.blur)
	end

	lg.push()
	lg.applyTransform(tf)
	lg.scale(1 / tf_scale_x, 1 / tf_scale_y)

	if backdrop.material then
		local shader = backdrop.material.shader
		shader:send(ShaderBuilder.buffer_name, backdrop.material.buffer)
		lg.setShader(shader)
		region_effect:draw()
		lg.setShader()
	else
		region_effect:draw()
	end

	lg.setColor(1, 1, 1)
	lg.setBlendMode("alpha")
	lg.pop()
	return 6
end

handlers[OP.DRAW_STYLE_CONTENT_ANY] = function(renderer, context, i)
	local style = context[i + 1] ---@type ui.Style
	local node = context[i + 2] ---@type ui.Node
	local tf = context[i + 3] ---@type love.Transform

	lg.push()
	lg.applyTransform(tf)
	lg.setShader(style.content.material.shader)
	lg.setColor(style.color)
	lg.setBlendMode(style.blend_mode, style.blend_mode_alpha)
	node:draw()
	lg.setColor(1, 1, 1, 1)
	lg.setBlendMode("alpha")
	lg.setShader()
	lg.pop()

	return 4
end

handlers[OP.DRAW_STYLE_CONTENT_TEXTURE] = function(renderer, context, i)
end

handlers[OP.DRAW_STYLE_CONTENT_NO_TEXTURE] = function(renderer, context, i)
	local style = context[i + 1] ---@type ui.Style
	local tf = context[i + 2] ---@type love.Transform

	lg.push()
	lg.applyTransform(tf)
	lg.setShader(style.content.material.shader)
	lg.setColor(style.color)
	lg.setBlendMode(style.blend_mode, style.blend_mode_alpha)
	lg.draw(renderer.pixel, 0, 0, 0, style.width, style.height)
	lg.setColor(1, 1, 1, 1)
	lg.setBlendMode("alpha")
	lg.setShader()
	lg.pop()

	return 3
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

--[[
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
]]

return Renderer
