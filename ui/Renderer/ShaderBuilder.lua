local class = require("class")
local BackgroundColor = require("ui.Renderer.Shader.BackgroundColor")
local LinearGradient = require("ui.Renderer.Shader.LinearGradient")
local Brightness = require("ui.Renderer.Shader.Brightness")
local BorderRadius = require("ui.Renderer.Shader.BorderRadius")
local Outline = require("ui.Renderer.Shader.Outline")
require("table.clear")

---@class ui.ShaderBuilder
---@operator call: ui.ShaderBuilder
---@field feature_set {[ui.ShaderFeature]: boolean} Temporary stores features used in a ui.Style
local ShaderBuilder = class()

ShaderBuilder.fields = {
	[BackgroundColor] = {
		"background_color"
	},
	[LinearGradient] = {
		"linear_gradient"
	},
	[Brightness] = {
		"brightness"
	},
	[BorderRadius] = {
		"border_radius",
	},
	[Outline] = {
		"border_width",
		"border_color"
	},
}

function ShaderBuilder:new()
	self.cache = {}
	self.feature_set = {}
end

---@param style ui.Style
---@return love.Shader?
function ShaderBuilder:addShader(style)
	table.clear(self.feature_set)
	table.clear(style.features)
	local has_features = false

	for feature, names in pairs(ShaderBuilder.fields) do
		for _, name in ipairs(names) do
			if style[name] then
				self:addFeatures(self.feature_set, feature)
				has_features = true
				break
			end
		end
	end

	if not has_features then
		return
	end

	for feature, _ in pairs(self.feature_set) do
		table.insert(style.features, feature)
	end

	table.sort(style.features, function(a, b)
		return a.layer < b.layer
	end)

	local key = ""

	for _, feature in ipairs(style.features) do
		key = ("%s + %s"):format(key, feature.name)
	end

	if self.cache[key] then
		return self.cache[key]
	end

	local code = "#pragma language glsl3\n"

	for _, feature in ipairs(style.features) do
		if feature.uniforms then
			for name, _type in pairs(feature.uniforms) do
				code = ("%sextern %s %s;\n"):format(code, _type, name)
			end
		end
	end

	for _, feature in ipairs(style.features) do
		if feature.functions then
			code = code .. feature.functions
		end
	end

	code = code .. [[
		vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
			vec4 tex_color = Texel(tex, uv);
	]]

	for _, feature in ipairs(style.features) do
		if feature.apply then
			code = code .. feature.apply
		end
	end

	code = code .. [[
			return tex_color * color;
		}
	]]

	style.shader = love.graphics.newShader(code)
end

---@param list {[ui.ShaderFeature]: boolean}
---@param feature ui.ShaderFeature
function ShaderBuilder:addFeatures(list, feature)
	list[feature] = true

	if not feature.requires then
		return
	end

	for _, v in ipairs(feature.requires) do
		self:addFeatures(list, v)
	end
end

return ShaderBuilder
