local IFeature = require("ui.material.IFeature")
local Struct = require("ui.material.shader.Struct")
local LinearGradientCode = require("ui.material.LinearGradientCode")

---@class ui.material.BackgroundColor : ui.IFeature
local BackgroundColor = IFeature + {}

BackgroundColor.id = "background_color"
BackgroundColor.layer = 0

---@class ui.material.BackgroundColor.Config
---@field fill "solid" | "linear_gradient"

---@class ui.material.BackgroundColor.Config.Solid : ui.material.BackgroundColor.Config
---@field color ui.Color

---@class ui.material.BackgroundColor.Config.Gradient : ui.material.BackgroundColor.Config
---@field colors ui.Color[]
---@field positions number[]
---@field angle number

---@param configs ui.BackgroundColor.Config[]
function BackgroundColor.validateConfig(config)
	config.fill = config.fill or "solid"

	if config.fill == "solid" then
		config.color = config.color or { 1, 1, 1, 1 }
	else
		config.colors = config.colors or {}
		config.positions = config.positions or {}
		config.angle = config.angle or 0
	end
end

---@param configs ui.BackgroundColor.Config[]
function BackgroundColor.getHash(configs)
	local names = {}
	for _, config in ipairs(configs) do
		if config.fill == "solid" then
			table.insert(names, "background_color")
		elseif config.fill == "linear_gradient" then
			---@cast config ui.BackgroundColor.Config.Gradient
			table.insert(names, ("background_color_linear_gradient%i"):format(#config.colors))
		else
			assert(config.fill, "Background color fill type is nil")
			error("Unknown fill type")
		end
	end
	return table.concat(names, " + ")
end

---@param configs ui.BackgroundColor.Config
---@param shader_code ui.Shader.Code
function BackgroundColor.build(configs, shader_code)
	for stack_index, config in ipairs(configs) do
		if config.fill == "solid" then
			BackgroundColor.buildSolid(shader_code, stack_index)
		elseif config.fill == "linear_gradient" then
			BackgroundColor.buildLinearGradient(config, shader_code, stack_index)
		else
			error("Missing config.fill or unknown fill type")
		end
	end

	local effect = shader_code.effect

	if #configs == 1 then
		effect:addLine("tex_color = bgc_result1;")
		return
	end

	effect:addLine("vec4 bgc_blend = bgc_result1;")

	local layer_count = #configs
	for i = 2, layer_count do
		effect:addLine(
			("bgc_blend.rgb = mix(bgc_blend.rgb, bgc_result%i.rgb, bgc_result%i.a);"):format(
				i, i
			)
		)
		effect:addLine(
			("bgc_blend.a = bgc_result%i.a + bgc_blend.a * (1.0 - bgc_result%i.a);"):format(
				i, i
			)
		)
	end

	effect:addLine("bgc_blend.rgb = mix(bgc_blend.rgb, tex_color.rgb, tex_color.a);")
	effect:addLine("bgc_blend.a = tex_color.a + bgc_blend.a * (1.0 - tex_color.a);")
	effect:addLine("tex_color = bgc_blend;")
end

---@param shader_code ui.Shader.Code
---@param stack_index integer
function BackgroundColor.buildSolid(shader_code, stack_index)
	shader_code.buffer:addField("vec4", "bgc_solid_color", stack_index)
	shader_code.effect:addLine(("vec4 bgc_result%i = material.bgc_solid_color%i;"):format(
		stack_index,
		stack_index
	))
end

---@param config ui.BackgroundColor.Config.Gradient
---@param shader_code ui.Shader.Code
---@param stack_index integer
function BackgroundColor.buildLinearGradient(config, shader_code, stack_index)
	local color_count = #config.colors
	local struct_key = ("Gradient%i"):format(color_count)

	if not shader_code.structs[struct_key] then
		local struct = Struct(struct_key)
		for i = 1, color_count do
			struct:addField("vec4", "color", i)
		end
		for i = 1, color_count - 1 do
			struct:addField("float", "position", i)
			struct:addField("float", "inv_diff", i)
		end
		struct:addField("vec2", "direction")
		shader_code.structs[struct_key] = struct
	end

	local instance_name = shader_code.buffer:addField(struct_key, "bgc_linear_gradient", stack_index)
	local apply_gradient_name = LinearGradientCode.getName(color_count)

	if not shader_code.functions[apply_gradient_name] then
		shader_code.functions[apply_gradient_name] = LinearGradientCode.generate(color_count)
	end

	shader_code.effect:addLine(
		("vec4 bgc_result%i = %s(material.%s, uv, sc);"):format(
			stack_index,
			apply_gradient_name,
			instance_name
		)
	)
end

---@param config ui.BackgroundColor.Config
function BackgroundColor.packArrayData(config, data)
	if config.fill == "solid" then
		---@cast config ui.BackgroundColor.Config.Solid
		IFeature.tableInsertArray(data, config.color)
		return
	end

	---@cast config ui.BackgroundColor.Config.Gradient

	local color_count = #config.colors
	for i = 1, color_count do
		IFeature.tableInsertArray(data, config.colors[i])
	end

	for i = 2, color_count do
		table.insert(data, config.positions[i - 1])                                        -- position
		table.insert(data, 1 / math.max(config.positions[i] - config.positions[i - 1], 0.00001)) -- inv_diff
	end

	table.insert(data, math.cos(config.angle))
	table.insert(data, math.sin(config.angle))
end

return BackgroundColor
