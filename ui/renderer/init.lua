local class = require("class")
local OP = require("ui.renderer.ops")
local RenderingContext = require("ui.renderer.RenderingContext")

---@class nya.Renderer
---@operator call: nya.Renderer
local Renderer = class()

local lg = love.graphics

function Renderer:new()
	self.viewport_scale = 1
	self.pixel = love.graphics.newCanvas(1, 1)
end

---@param root view.Node
function Renderer:build(root)
end

---@param scale number
function Renderer:setViewportScale(scale)
	self.viewport_scale = scale

	local ww, wh = lg.getDimensions()
	if not self.canvas or self.canvas:getWidth() ~= ww or self.canvas:getHeight() ~= wh then
		self.main_canvas = lg.newCanvas(ww, wh)
	end
end

---@param node view.Node
local function drawNode(node)
	lg.push("all")
	lg.applyTransform(node.transform:get())
	node:draw()
	lg.pop()
end

local function ()
	
end

function Renderer:draw()
	self.current_canvas = self.main_canvas
	lg.setCanvas({ self.current_canvas, stencil = true })
	lg.clear()

	lg.setCanvas()
	lg.origin()
	lg.setColor(1, 1, 1)
	lg.draw(self.main_canvas)
end

return Renderer
