local class = require("class")
local RenderingContext = require("ui.renderer.RenderingContext")

---@class nya.Renderer
---@operator call: nya.Renderer
local Renderer = class()

local lg = love.graphics
local lg_push = lg.push
local lg_pop = lg.pop
local lg_applyTransform = lg.applyTransform
local lg_setColor = lg.setColor
local lg_setBlendMode = lg.setBlendMode

function Renderer:new()
	self.viewport_scale = 1
	self.pixel = love.graphics.newCanvas(1, 1)
end

---@param scale number
function Renderer:setViewportScale(scale)
	self.viewport_scale = scale

	local ww, wh = lg.getDimensions()
	if not self.canvas or self.canvas:getWidth() ~= ww or self.canvas:getHeight() ~= wh then
		self.main_canvas = lg.newCanvas(ww, wh)
	end
end

---@param root view.Node
function Renderer:build(root)
	self.ctx = RenderingContext:build(root)
end

local canvas_apply = { stencil = true }

function Renderer:draw()
	self.current_canvas = self.main_canvas
	canvas_apply[1] = self.current_canvas
	lg.setCanvas(canvas_apply)
	lg.clear()
	lg.origin()
	lg.setColor(1, 1, 1)

	local OP = RenderingContext.Operations
	local ctx = self.ctx
	local l = #ctx
	local i = 1
	while i <= l do
		local v = ctx[i]

		if v == OP.PUSH_STATE then
			lg_push("all")
			i = i + 1
		elseif v == OP.POP_STATE then
			lg_pop()
			i = i + 1
		elseif v == OP.DRAW then
			local node = ctx[i + 1]
			lg_applyTransform(node.transform:get())
			node:draw()
			i = i + 2
		elseif v == OP.SET_COLOR then
			lg_setColor(ctx[i + 1].color)
			i = i + 2
		elseif v == OP.SET_BLEND_MODE then
			lg_setBlendMode(
				ctx[i + 1],
				ctx[i + 2]
			)
			i = i + 3
		else
			error("Unknown operation")
		end
	end

	lg.setCanvas()
	lg.draw(self.main_canvas)
end

return Renderer
