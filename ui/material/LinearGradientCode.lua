local ShaderFunction = require("ui.material.shader.Function")

local LinearGradientCode = {}

---@param color_count integer
---@return string
function LinearGradientCode.getName(color_count)
	return ("applyLinearGradient%i"):format(color_count)
end

---@param color_count integer
---@return ui.Shader.Function
function LinearGradientCode.generate(color_count)
	local struct_name = ("Gradient%i"):format(color_count)
	local func_name = LinearGradientCode.getName(color_count)
	local fn = ShaderFunction("vec4", func_name)
	fn:addArgument(struct_name, "grad")
	fn:addArgument("vec2", "uv")
	fn:addArgument("vec2", "sc")

	fn:addLine("vec2 centered_uv = uv - vec2(0.5);")
	fn:addLine("float t = dot(centered_uv, grad.direction);")
	fn:addLine("float max_proj = 0.5 * (abs(grad.direction.x) + abs(grad.direction.y));")
	fn:addLine("t = 0.5 + t / (2.0 * max_proj);")
	fn:addLine("vec4 result = grad.color1;")

	for i = 1, color_count - 1 do
		local p1 = "grad.position" .. i
		local inv_diff = "grad.inv_diff" .. i
		local next_color = "grad.color" .. (i + 1)

		fn:addLine(string.format(
			"result = mix(result, %s, clamp((t - %s) * %s, 0.0, 1.0));",
			next_color, p1, inv_diff
		))
	end

	fn:addLine("vec2 noiseUV = floor(sc * vec2(800.0, 600.0));")
	fn:addLine("float noise = fract(sin(dot(sc.xy, vec2(12.9898, 78.233))) * 43758.5453123);")
	fn:addLine("result.rgb += (noise - 0.5) / 64.0;")
	fn:addLine("return result;")
	return fn
end

return LinearGradientCode
