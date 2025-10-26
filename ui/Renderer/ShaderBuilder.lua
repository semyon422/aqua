local class = require("class")
local LinearGradient = require("ui.Renderer.Shader.LinearGradient")
local Outline = require("ui.Renderer.Shader.Outline")
local BorderRadius = require("ui.Renderer.Shader.BorderRadius")
require("table.clear")

---@class ui.ShaderBuilder
---@operator call: ui.ShaderBuilder
local ShaderBuilder = class()

local fields = {
	[LinearGradient] = {
		"linear_gradient"
	},
	[Outline] = {
		"border_width",
		"border_color"
	},
	[BorderRadius] = {
		"border_radius",
	}
}

function ShaderBuilder:new()
	self.cache = {}
end

---@param style ui.Style
---@return love.Shader?
function ShaderBuilder:addShader(style)
	table.clear(style.features)

	for feature, names in pairs(fields) do
		for _, name in ipairs(names) do
			if style[name] then
				table.insert(style.features, feature)
				break
			end
		end
	end

	if #style.features == 0 then
		return
	end

	for _, feature in ipairs(style.features) do
		self:addRequires(style.features, feature)
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

	local code = ""

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
			return tex_color;
		}
	]]

	print(code)
	style.shader = love.graphics.newShader(code)
end

---@param list ui.ShaderFeature[]
---@param feature ui.ShaderFeature
function ShaderBuilder:addRequires(list, feature)
	if not feature.requires then
		return
	end

	for _, feature in ipairs(feature.requires) do
		for _, existing_feature in ipairs(list) do
			if feature == existing_feature then
				return
			end
		end

		table.insert(list, feature)
		self:addRequires(list, feature)
	end
end

return ShaderBuilder
