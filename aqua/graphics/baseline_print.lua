local baseline_print = function(text, x, baseline, limit, scale, ax)
	local font = love.graphics.getFont()

	local y = baseline - font:getBaseline() * scale

	local status, err = pcall(
		love.graphics.printf,
		text,
		x,
		y,
		limit,
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
			limit,
			ax,
			0,
			scale,
			scale
		)
	end
end

return baseline_print
