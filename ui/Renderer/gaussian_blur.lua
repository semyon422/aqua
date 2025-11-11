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
---@return love.Shader
local function getShader(radius, sigma, is_vertical)
	local weights = getWeights(radius, sigma)
	local step = is_vertical and "vec2(0.0, 1.0 / tex_size.y)" or "vec2(1.0 / tex_size.x, 0.0)"

	local code = ([[
		extern vec2 tex_size;
		extern vec2 uv_min;
		extern vec2 uv_max;

		vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc)
		{
			vec2 step = %s;
			vec4 sum = vec4(0.0);
			vec2 coord;
	]]):format(step)

	for i = -radius, radius do
		code = code .. ("coord = tc + step * %.1f;\n"):format(i)
		code = code .. "coord = clamp(coord, uv_min, uv_max);\n"
		code = code .. ("sum += Texel(tex, coord) * %.9f;\n"):format(weights[i])
	end

	code = code .. [[
		return sum * color;
	}
	]]

	return love.graphics.newShader(code)
end

---@param radius number
---@return love.Shader horizontal
---@return love.Shader vertical
return function(radius)
	local sigma = radius / 2
	return getShader(radius, sigma, false), getShader(radius, sigma, true)
end
