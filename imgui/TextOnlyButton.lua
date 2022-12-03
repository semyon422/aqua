local just = require("just")
local theme = require("imgui.theme")
local gfx_util = require("gfx_util")

return function(id, text, w, h, align)
	local mx, my = love.graphics.inverseTransformPoint(love.mouse.getPosition())
	local over = 0 <= mx and mx <= w and 0 <= my and my <= h

	local changed, active, hovered = just.button(id, over)
	theme.setColorBoundless(active, hovered)
	love.graphics.rectangle("fill", 0, 0, w, h)

	local font = love.graphics.getFont()
	local fh = font:getHeight()
	local p = 0

	align = align or "center"
	if align ~= "center" then
		p = (h - fh) / 2
	end

	love.graphics.setColor(1, 1, 1, 1)
	gfx_util.printFrame(text, p, 0, w - p * 2, h, align, "center")

	just.next(w, h)

	return changed
end
