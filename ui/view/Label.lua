local Node = require("ui.view.Node")

---@class view.Label : view.Node
---@operator call: view.Label
---@field font love.Font
---@field font_size number
---@field text string
local Label = Node + {}

---@class view.Label.Setters : view.Node.Setters
Label.Set = Node.Set + {}

-- TODO:
-- Thickness
-- Outline
-- Glow
-- Drop shadow

---@param label view.Label
---@param v love.Font
Label.Set.font = function(label, v)
	label.font = v
	label.text_batch_dirty = true
end

---@param label view.Label
---@param v number
Label.Set.font_size = function(label, v)
	label.font_size = v
	label.text_batch_dirty = true -- TODO: don't mark it dirty, just update the scale
end

Label.Set.text = function(label, v)
	if label.text == v then
		return
	end
	label.text = v
	label.text_batch_dirty = true
end

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

function Label:new()
	Node.new(self)
	self.text_batch_dirty = false
end

local function nop() end

local function draw(self)
	love.graphics.setShader(shader)
	love.graphics.draw(self.text_batch, 0, 0, 0, self.scale, self.scale)
end

function Label:updateTextBatch()
	if not self.font or not self.text then
		self.draw = nop
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
	self.draw = draw
	self.text_batch_dirty = false
end

function Label:update()
	if self.text_batch_dirty then
		self:updateTextBatch()
	end
end


return Label
