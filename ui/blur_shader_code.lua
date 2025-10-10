---@param radius number
---@param sigma number
---@return number[]
local function getWeights(radius, sigma)
	local weights = {}
	local sum = 0

	for i = -radius, radius do
		local w = math.exp(-(i * i) / (2 * sigma * sigma))
		weights[i] = w
		sum = sum + w
	end

	for i = -radius, radius do
		weights[i] = weights[i] / sum
	end

	return weights
end

---@param radius number
---@param sigma number
---@param is_vertical boolean
---@return string
local function getShader(radius, sigma, is_vertical)
	local weights = getWeights(radius, sigma)
	local step = is_vertical and "vec2(0.0, 1.0 / tex_size.y)" or "vec2(1.0 / tex_size.x, 0.0)"

	local code = ([[
		extern vec2 tex_size;

		vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc)
		{
			vec2 step = %s;
			vec4 sum = vec4(0.0);
	]]):format(step)

	for i = -radius, radius do
		code = code .. ("sum += Texel(tex, tc + step * %.1f) * %.9f;\n"):format(i, weights[i])
	end

	code = code .. [[
		return sum * color;
	}
	]]

	return code
end

---@param radius number
---@return string horizontal_shader_code
---@return string vertical_shader_code
return function(radius)
	local sigma = radius / 2
	return getShader(radius, sigma, false), getShader(radius, sigma, true)
end
