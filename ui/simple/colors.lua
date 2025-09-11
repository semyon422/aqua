local function rgb(r, g, b)
	r, g, b = love.math.colorFromBytes(r, g, b)
	return { r, g, b, 1 }
end

return {
	unpack = function(c)
		return c[1], c[2], c[3], c[4]
	end,

	text = rgb(255, 255, 255),
	background = rgb(20, 22, 26),
	border = rgb(53, 58, 70),

	palette_1 = rgb(162, 210, 255),
	palette_2 = rgb(189, 224, 254),
	palette_3 = rgb(255, 175, 204),
	palette_4 = rgb(255, 200, 221),
	palette_5 = rgb(205, 180, 219)
}
