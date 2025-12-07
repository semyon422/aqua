local Node = require("ui.view.Node")

---@class view.Label : view.Node
---@operator call: view.Label
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

---@param params { text: string?, font: love.Font, font_size: number }
function Label:init(params)
	self.text = ""
	Node.init(self, params)

	self.font = assert(params.font, "Expected font, got nil")
	self.font_size = assert(params.font_size, "Expected font_size, got nil")
	self.text_batch = love.graphics.newTextBatch(self.font, self.text)
	self:updateDimensions()

	if not default_shader then
		default_shader = love.graphics.newShader(default_shader_code)
	end
end

function Label:updateDimensions()
	local w, h = self.text_batch:getDimensions()
	self.scale = self.font_size / self.font:getHeight()
	self.layout_box:setDimensions(w * self.scale, h * self.scale)
end

---@param text string
function Label:setText(text)
	if self.text == text then
		return
	end
	self.text = text
	self.text_batch:set(text)
	self:updateDimensions()
end

function Label:draw()
	love.graphics.setShader(love.graphics.getShader() or default_shader)
	love.graphics.draw(self.text_batch, 0, 0, 0, self.scale, self.scale)
end

return Label
