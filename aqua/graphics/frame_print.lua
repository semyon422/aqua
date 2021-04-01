local frame_print = function(text, x, y, w, h, scale, ax, ay)
	local font = love.graphics.getFont()

	local scaledLimit = w / scale

	local width, wrappedText = 0, ""
	local status, err1, err2 = pcall(font.getWrap, font, text, scaledLimit)
	if status then
		width, wrappedText = err1, err2
	else
		width, wrappedText = font:getWrap(err1, scaledLimit)
	end

	local lineCount = #wrappedText

	if ay == "center" then
		y = y + (h - font:getHeight() * lineCount * scale) / 2
	elseif ay == "bottom" then
		y = y + h - font:getHeight() * lineCount * scale
	end

	local status, err = pcall(
		love.graphics.printf,
		text,
		x,
		y,
		scaledLimit,
		ax,
		0,
		scale,
		scale
	)
	if not status then
		love.graphics.printf(
			err,
			x,
			y,
			scaledLimit,
			ax,
			0,
			scale,
			scale
		)
	end
end

return frame_print
