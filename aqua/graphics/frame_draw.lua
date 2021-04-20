local frame_draw = function(drawable, x, y, w, h, locate)
    local dw = drawable:getWidth()
    local dh = drawable:getHeight()

	local scale = 1
	local s1 = w / h <= dw / dh
	local s2 = w / h >= dw / dh

	if locate == "out" and s1 or locate == "in" and s2 then
		scale = h / dh
	elseif locate == "out" and s2 or locate == "in" and s1 then
		scale = w / dw
	end

    return love.graphics.draw(
		drawable,
		x + (w - dw * scale) / 2,
		y + (h - dh * scale) / 2,
		0,
		scale,
		scale
	)
end

return frame_draw
