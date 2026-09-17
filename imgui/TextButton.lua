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

	if inactive then
		theme.setMutedColor()
	else
		theme.setTextColor()
	end

	gfx_util.printFrame(tostring(text), 0, 0, w, h, "center", "center")
	theme.setTextColor()

	just.next(w, h)

	return changed
end
