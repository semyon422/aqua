local just = require("just")
local theme = require("imgui.theme")
local gfx_util = require("gfx_util")

return function(id, text, w, h, inactive)
	local changed, active, hovered = just.button(id, just.is_over(w, h))

	if inactive then
		changed, active, hovered = false, false, false
	end

	theme.setColor(active, hovered)
	theme.rectangle(w, h)

	love.graphics.setColor(1, 1, 1, 1)
	if inactive then
		love.graphics.setColor(0.5, 0.5, 0.5, 1)
	end

	gfx_util.printFrame(tostring(text), 0, 0, w, h, "center", "center")

	just.next(w, h)

	return changed
end
