local just = require("just")
local gfx_util = require("gfx_util")
local theme = require("imgui.theme")

return function(id, v, text, w, h)
	local changed, active, hovered = just.button(id, just.is_over(w, h))

	theme.setColor(active, hovered)
	theme.rectangle(w, h)

	love.graphics.setColor(1, 1, 1, 1)
	if v then
		theme.fillrect(w, h)
		love.graphics.setColor(0, 0, 0, 1)
	end
	gfx_util.printFrame(tostring(text), 0, 0, w, h, "center", "center")

	love.graphics.setColor(1, 1, 1, 1)

	just.next(w, h)

	return changed
end
