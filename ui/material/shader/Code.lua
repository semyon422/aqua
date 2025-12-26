local class = require("class")
local ShaderStruct = require("ui.material.shader.Struct")
local ShaderFunction = require("ui.material.shader.Function")

---@class ui.Shader.Code
---@operator call: ui.Shader.Code
---@field structs {[string]: ui.Shader.Struct}
---@field functions {[string]: ui.Shader.Function}
---@field buffer ui.Shader.Struct
---@field effect ui.Shader.Function
local ShaderCode = class()

function ShaderCode:new()
	self.buffer = ShaderStruct("Material")
	self.structs = {}
	self.functions = {}
	self.effect = ShaderFunction("vec4", "effect")
	self.effect:addArgument("vec4", "color")
	self.effect:addArgument("Image", "tex")
	self.effect:addArgument("vec2", "uv")
	self.effect:addArgument("vec2", "sc")
	self.effect:addLine("vec4 tex_color = Texel(tex, uv);")
end

---@param feature ui.IFeature
---@param config ui.FeatureConfig[]
function ShaderCode:addFeature(feature, configs)
	feature.build(configs, self)
end

local template = [[
#pragma language glsl4

// ==== STRUCTS ====
%s

// ==== BUFFER ====
%s


layout(std430) readonly buffer material_buffer {
	Material _material[];
};

Material material = _material[0];

// ==== FUNCTIONS ====
%s

// ==== EFFECT ====
%s
]]

---@return boolean success
---@return string code_or_error
function ShaderCode:build()
	self.effect:addLine("return tex_color * color;")

	local struct_arr = {}
	local function_arr = {}
	for _, v in pairs(self.structs) do
		table.insert(struct_arr, tostring(v))
	end
	for _, v in pairs(self.functions) do
		table.insert(function_arr, tostring(v))
	end

	local code = template:format(
		table.concat(struct_arr, "\n"),
		tostring(self.buffer),
		table.concat(function_arr, "\n"),
		tostring(self.effect)
	)

	local valid, message = love.graphics.validateShader(false, code)

	if not valid then
		print(code)
		print("\027[31m==== MATERIAL SHADER COMPILATION ERROR ====\027[0m")
		print(message)
	end
	return valid, code
end

return ShaderCode
