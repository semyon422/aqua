local class = require("class")
local gaussian_blur = require("ui.Renderer.gaussian_blur")

---@class ui.RegionEffect
---@operator call: ui.RegionEffect
local RegionEffect = class()

local lg = love.graphics

---@param screen_width number
---@param screen_height number
function RegionEffect:new(screen_width, screen_height)
	self.screen_width = screen_width
	self.screen_height = screen_height
	self.buffer_a = lg.newCanvas(screen_width, screen_height)
	self.buffer_b = lg.newCanvas(screen_width, screen_height)
	self.buffer_a:setWrap("clamp", "clamp")
	self.buffer_b:setWrap("clamp", "clamp")
	self.current_buffer = self.buffer_a
	self.previous_buffer = self.buffer_b

	self.quad = lg.newQuad(0, 0, 1, 1, self.buffer_a)

	self.capture_width = 0
	self.capture_height = 0
	self.padding = 0

	self.gaussian = {}
end

function RegionEffect:nextBuffer()
	self.previous_buffer = self.current_buffer
	self.current_buffer = self.current_buffer == self.buffer_a and self.buffer_b or self.buffer_a
end

---@param source_canvas love.Canvas
---@param width number
---@param height number
---@param padding number?
function RegionEffect:setCaptureRegion(source_canvas, width, height, padding)
	self.source_canvas = source_canvas
	self.capture_width = math.floor(width)
	self.capture_height = math.floor(height)
	self.padding = math.max(0, padding or 0)
end

function RegionEffect:captureRegion()
	local p = self.padding
	lg.push("all")
	lg.setCanvas(self.current_buffer)
	lg.setBlendMode("replace")
	lg.setScissor(0, 0, self.capture_width + p * 2, self.capture_height + p * 2)
	lg.draw(self.source_canvas, p, p)
	lg.pop()
end

function RegionEffect:draw()
	self.quad:setViewport(0, 0, self.capture_width, self.capture_height)
	lg.draw(self.current_buffer, self.quad)
end

local size = { 0, 0 }
local uv_scale = { 0, 0 }

---@param blur ui.Style.Blur
function RegionEffect:applyBlur(blur)
	if blur.type == "gaussian" then
		self:applyGaussianBlur(blur.radius, 0.5)
	else
		error("Not implemented")
	end
end

---@param radius integer
---@param downsample_scale number
function RegionEffect:applyGaussianBlur(radius, downsample_scale)
	if not self.gaussian[radius] then
		self.gaussian[radius] = { gaussian_blur(radius) }
	end

	local horizontal, vertical = self.gaussian[radius][1], self.gaussian[radius][2]

	local upsample_scale = 1 / downsample_scale
	local prev_canvas = lg.getCanvas()

	local p = self.padding
	local canvas_width = self.current_buffer:getWidth()
	local canvas_height = self.current_buffer:getHeight()
	local capture_width = self.capture_width + p * 2
	local capture_height = self.capture_width + p * 2

	size[1] = canvas_width
	size[2] = canvas_height
	size[1] = canvas_width
	size[2] = canvas_height
	horizontal:send("tex_size", size)
	vertical:send("tex_size", size)

	lg.setBlendMode("replace")

	self:nextBuffer()
	lg.setCanvas(self.current_buffer)
	lg.setShader(horizontal)
	lg.push()
	lg.scale(downsample_scale)
	lg.setScissor(0, 0, capture_width, capture_height)
	lg.draw(self.previous_buffer)
	lg.pop()

	self:nextBuffer()
	lg.setCanvas(self.current_buffer)
	lg.setShader(vertical)
	lg.push()
	lg.translate(-self.padding, -self.padding)
	lg.scale(upsample_scale)
	lg.setScissor(0, 0, capture_width - self.padding * 2, capture_height - self.padding * 2)
	lg.draw(self.previous_buffer)
	lg.pop()

	lg.setCanvas(prev_canvas)
	lg.setShader()
	lg.setScissor()
	lg.setBlendMode("alpha")
end

return RegionEffect
