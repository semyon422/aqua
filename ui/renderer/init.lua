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
local lg_stencil = lg.stencil
local lg_setStencilTest = lg.setStencilTest
local lg_rectangle = lg.rectangle

function Renderer:new()
	self.viewport_scale = 1
	self.pixel = love.graphics.newCanvas(1, 1)
end

---@param scale number
function Renderer:setViewportScale(scale)
	self.viewport_scale = scale

	local ww, wh = lg.getDimensions()
	if not self.main_canvas or self.main_canvas:getWidth() ~= ww or self.main_canvas:getHeight() ~= wh then
		self.main_canvas = lg.newCanvas(ww, wh)
	end
end

---@param root view.Node
function Renderer:build(root)
	self.ctx = RenderingContext:build(root)
end

local canvas_apply = { stencil = true }
local stencil_w = 0
local stencil_h = 0
local stencil_tf = nil ---@type love.Transform

local function stencil()
	lg_push()
	lg_applyTransform(stencil_tf)
	lg_rectangle("fill", 0, 0, stencil_w, stencil_h)
	lg_pop()
end

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
			lg_push()
			lg_applyTransform(node.transform:get())
			node:draw()
			lg_pop()
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
		elseif v == OP.SET_STENCIL then
			local node = ctx[i + 1]
			stencil_w = node:getCalculatedWidth()
			stencil_h = node:getCalculatedHeight()
			stencil_tf = node.transform:get()
			lg_stencil(stencil, "replace", 1)
			lg_setStencilTest("greater", 0)
			i = i + 2
		else
			error("Unknown operation")
		end
	end

	lg.setCanvas()
	lg.draw(self.main_canvas)
end

return Renderer
