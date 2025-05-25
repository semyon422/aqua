local just = require("just")
local theme = require("imgui.theme")

return function(id, v, size, inactive)
	local changed, active, hovered = just.button(id, just.is_over(size, size))

	if inactive then
		changed, active, hovered = false, false, false
	end

	theme.setColor(active, hovered)
	theme.rectangle(size, size)

	love.graphics.setColor(1, 1, 1, 1)
	if inactive then
		love.graphics.setColor(0.5, 0.5, 0.5, 1)
	end

	if v then
		theme.fillrect(size)
	end
	love.graphics.setColor(1, 1, 1, 1)

	just.next(size, size)

	return changed
end
