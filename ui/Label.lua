local Node = require("ui.Node")
local Fonts = require("ui.Fonts")

---@class ui.Label : ui.Node
---@operator call: ui.Label
---@field font love.Font
---@field font_size number
---@field text string
local Label = Node + {}

Label.ClassName = "Label"

local default_shader_code = [[
	vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
		float dist = Texel(tex, uv).a;
		float edge_width = length(vec2(dFdx(dist), dFdy(dist)));
		float edge_distance = 0.5;
		float opacity = smoothstep(edge_distance - edge_width, edge_distance + edge_width, dist);
		color.a *= opacity;
		return color;
	}
]]

local default_shader ---@type love.Shader

function Label:new(params)
	self.text = ""
	Node.new(self, params)
	self:assert(self.font, "Font expected")
	self:assert(self.font_size, "Font size expected")

	if not default_shader then
		default_shader = love.graphics.newShader(default_shader_code)
	end

	self.text_batch = love.graphics.newTextBatch(self.font, self.text)
	self:setDimensions(self.text_batch:getDimensions())
end

---@param w number
---@param h number
function Label:setDimensions(w, h)
	self.scale = self.font_size / Fonts.FontSize
	Node.setDimensions(self, w * self.scale, h * self.scale)
end

---@param text string
function Label:setText(text)
	if self.text == text then
		return
	end
	self.text = text
	self.text_batch:set(text)
	self:setDimensions(self.text_batch:getDimensions())
end

function Label:draw()
	love.graphics.setShader(love.graphics.getShader() or default_shader)
	love.graphics.draw(self.text_batch, 0, 0, 0, self.scale, self.scale)
end

return Label
