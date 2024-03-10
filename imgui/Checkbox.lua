local just = require("just")
local theme = require("imgui.theme")

return function(id, v, size)
	local changed, active, hovered = just.button(id, just.is_over(size, size))

	theme.setColor(active, hovered)
	theme.rectangle(size, size)

	love.graphics.setColor(1, 1, 1, 1)
	if v then
		theme.fillrect(size)
	end

	just.next(size, size)

	return changed
end
