local just = require("just")
local theme = require("imgui.theme")

return function(id, v, size, inactive)
	local changed, active, hovered = just.button(id, just.is_over(size, size))

	if inactive then
		changed, active, hovered = false, false, false
	end

	theme.setColor(active, hovered)
	theme.rectangle(size, size)

	if inactive then
		theme.setMutedColor()
	else
		theme.setTextColor()
	end

	if v then
		theme.setAccentColor()
		theme.fillrect(size)
	end
	theme.setTextColor()

	just.next(size, size)

	return changed
end
