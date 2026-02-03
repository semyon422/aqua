local Node = require("ui.view.Node")

-- TODO:
-- Thickness
-- Outline
-- Glow
-- Drop shadow

---@class view.Label : view.Node
---@operator call: view.Label
---@field font love.Font
---@field font_size number
---@field text string
local Label = Node + {}

local shader = love.graphics.newShader([[
	vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
		float dist = Texel(tex, uv).a;
		float edge_width = length(vec2(dFdx(dist), dFdy(dist)));
		float edge_distance = 0.5;
		float opacity = smoothstep(edge_distance - edge_width, edge_distance + edge_width, dist);
		color.a *= opacity;
		return color;
	}
]])

---@param v love.Font
function Label:setFont(v)
	if self.font == v then
		return
	end
	self.font = v
	self.text_batch_dirty = true
end

---@param v number
function Label:setFontSize(v)
	if self.font_size == v then
		return
	end
	self.font_size = v
	self.text_batch_dirty = true
end

---@param v string
function Label:setText(v)
	if self.text == v then
		return
	end
	self.text = v
	self.text_batch_dirty = true
end

function Label:updateTextBatch()
	self.text_batch_dirty = false
	self.text = self.text or ""

	if not self.font then
		return
	end

	if self.text_batch then
		self.text_batch:set(self.text)
	else
		self.text_batch = love.graphics.newTextBatch(self.font, self.text)
	end

	local w, h = self.text_batch:getDimensions()
	self.scale = self.font_size / self.font:getHeight()
	self.layout_box:setDimensions(w * self.scale, h * self.scale)
end

function Label:update()
	if self.text_batch_dirty then
		self:updateTextBatch()
	end
end

function Label:draw()
	love.graphics.setShader(shader)
	love.graphics.draw(self.text_batch, 0, 0, 0, self.scale, self.scale)
end

Label.Setters = setmetatable({
	font = Label.setFont,
	font_size = Label.setFontSize,
	text = Label.setText
}, { __index = Node.Setters })

return Label
