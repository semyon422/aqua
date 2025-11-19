local class = require("class")
local OP = require("ui.Renderer.ops")
local RenderingContext = require("ui.Renderer.RenderingContext")
local RegionEffect = require("ui.Renderer.RegionEffect")
local ShaderBuilder = require("ui.Renderer.ShaderBuilder")

---@class ui.Renderer
---@operator call: ui.Renderer
local Renderer = class()

local lg = love.graphics

---@type fun(renderer: ui.Renderer, context: any[], i: integer)
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
		self.main_canvas = lg.newCanvas(ww, wh)
		self.region_effect = RegionEffect(ww, wh)
	end
end

function Renderer:draw()
	self.current_canvas = self.main_canvas
	lg.setCanvas({ self.current_canvas, stencil = true })
	lg.clear()

	local ctx = self.context.ctx
	local i, n = 1, self.context.ctx_size
	while i <= n do
		i = i + handlers[ctx[i]](self, ctx, i)
	end

	lg.setCanvas()
	lg.origin()
	lg.setColor(1, 1, 1)
	lg.draw(self.main_canvas)
end

handlers[OP.UPDATE_STYLE] = function(renderer, context, i)
	local style = context[i + 1] ---@type ui.Style
	style:updateMaterials()
	return 2
end

handlers[OP.DRAW_STYLE_SHADOW] = function(renderer, context, i)
	local style = context[i + 1] ---@type ui.Style
	local tf = context[i + 2] ---@type love.Transform

	local shadow = style.shadow ---@cast shadow -?
	local r = shadow.radius
	lg.push()
	lg.applyTransform(tf)
	lg.setShader(style.shadow.material.shader)
	lg.draw(renderer.pixel, shadow.x + -r, shadow.y + -r, 0, style.width + r * 2, style.height + r * 2)
	lg.setShader()
	lg.pop()

	return 3
end

---@param renderer ui.Renderer
---@param context any[]
---@param i integer
handlers[OP.DRAW_STYLE_BACKDROP] = function(renderer, context, i)
	local style = context[i + 1] ---@type ui.Style
	local node = context[i + 2] ---@type ui.Node
	local tf = node.transform
	local i_tf = node.inverse_transform
	local tf_scale_x = context[i + 3] ---@type number
	local tf_scale_y = context[i + 4] ---@type number
	local region_effect = renderer.region_effect ---@type ui.RegionEffect
	local current_canvas = renderer.current_canvas ---@type love.Canvas
	local backdrop = style.backdrop ---@type ui.Style.Backdrop

	local visual_width, visual_height = style.width * tf_scale_x, style.height * tf_scale_y
	local ww, wh = love.graphics.getDimensions()
	style:setBackdropUvScale(visual_width / ww, visual_height / wh)

	lg.push()
	lg.scale(tf_scale_x, tf_scale_y)
	lg.applyTransform(i_tf)
	region_effect:setCaptureRegion(
		current_canvas,
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

	local shader = backdrop.material.shader
	lg.setShader(shader)
	region_effect:draw()
	lg.setShader()

	lg.setColor(1, 1, 1)
	lg.setBlendMode("alpha")
	lg.pop()
	return 5
end

---@param renderer ui.Renderer
---@param context any[]
---@param i integer
handlers[OP.DRAW] = function(renderer, context, i)
	local node = context[i + 1]
	lg.push("all")
	lg.applyTransform(node.transform)
	node:draw()
	lg.pop()
	return 2
end

handlers[OP.DRAW_STYLE_CONTENT_SELF_DRAW] = function(renderer, context, i)
	local style = context[i + 1] ---@type ui.Style
	local node = context[i + 2] ---@type ui.Node
	local tf = context[i + 3] ---@type love.Transform
	local content = style.content ---@cast content -?

	lg.push()
	lg.applyTransform(tf)
	lg.setShader(content.material.shader)
	lg.setColor(content.color)
	lg.setBlendMode(content.blend_mode, content.blend_mode_alpha)
	node:draw()
	lg.setColor(1, 1, 1, 1)
	lg.setBlendMode("alpha")
	lg.setShader()
	lg.pop()

	return 4
end

handlers[OP.DRAW_STYLE_CONTENT] = function(renderer, context, i)
	local style = context[i + 1] ---@type ui.Style
	local tf = context[i + 2] ---@type love.Transform
	local content = style.content ---@cast content -?

	lg.push()
	lg.applyTransform(tf:get())
	lg.setShader(content.material.shader)
	lg.setColor(content.color)
	lg.setBlendMode(content.blend_mode, content.blend_mode_alpha)
	lg.draw(renderer.pixel, 0, 0, 0, style.width, style.height)
	lg.setColor(1, 1, 1, 1)
	lg.setBlendMode("alpha")
	lg.setShader()
	lg.pop()

	return 3
end

handlers[OP.DRAW_STYLE_CONTENT_CACHE] = function(renderer, context, i)
	local style = context[i + 1] ---@type ui.Style
	local tf = context[i + 2] ---@type love.Transform
	local cache = style.content_cache ---@cast cache -?

	local tf_x, tf_y = tf.transform_scale_x, tf.transform_scale_y
	lg.push()
	lg.scale(1 / tf_x, 1 / tf_y)
	lg.applyTransform(tf:get())
	lg.setShader(cache.material.shader)
	lg.setColor(cache.color)
	lg.setBlendMode(cache.blend_mode, cache.blend_mode_alpha)
	lg.draw(cache.canvas)
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

---@param renderer ui.Renderer
---@param context any[]
---@param i integer
handlers[OP.STYLE_CONTENT_CACHE_BEGIN] = function(renderer, context, i)
	local node = context[i + 1] ---@type ui.Node
	local style = node.style ---@cast style -?
	local cache = style.content_cache ---@cast cache -?

	if not cache.needs_redraw then
		local end_index = i
		while context[end_index] ~= OP.STYLE_CONTENT_CACHE_END do
			end_index = end_index + 1
		end
		return end_index - i + 1
	end

	local tf_x, tf_y = node.transform.transform_scale_x, node.transform.transform_scale_y
	local tf_inverse = node.transform:getInverse()
	local w = math.ceil(style.width * renderer.viewport_scale)
	local h = math.ceil(style.height * renderer.viewport_scale)

	if not cache.canvas or
		cache.canvas:getWidth() ~= w or
		cache.canvas:getHeight() ~= h
	then
		cache.canvas = lg.newCanvas(w, h)
	end

	lg.push("all")
	renderer.current_canvas = cache.canvas
	lg.setCanvas({ cache.canvas, stencil = true })
	lg.setBlendMode("alpha", "alphamultiply")
	lg.scale(1 / tf_x, 1 / tf_y)
	lg.applyTransform(tf_inverse)
	lg.clear()

	cache.needs_redraw = false
	return 2
end

---@param renderer ui.Renderer
---@param context any[]
---@param i integer
handlers[OP.STYLE_CONTENT_CACHE_END] = function(renderer, context, i)
	lg.pop()
	renderer.current_canvas = renderer.main_canvas
	return 1
end

return Renderer
