local just = require("just")
local gfx_util = require("gfx_util")
local theme = require("imgui.theme")

return function(id, text, w, h)
	local changed = false
	local key, device, device_id

	if just.focused_id == id then
		local k, dev, dev_id = just.next_input("pressed")
		if k then
			key, device, device_id = k, dev, dev_id
			changed = true
			just.focus()
		end
		if just.keypressed("escape", true) then
			changed = true
			key, device, device_id = nil, nil, nil
			just.focus()
		end
	end

	local _changed, active, hovered = just.button(id, just.is_over(w, h))
	if _changed then
		just.focus(id)
		active = true
	end

	theme.setColor(just.focused_id == id or active, hovered)
	theme.rectangle(w, h)

	love.graphics.setColor(1, 1, 1, 1)

	text = just.focused_id == id and "●" or text or "none"
	gfx_util.printFrame(text, 0, 0, w, h, "center", "center")

	just.next(w, h)

	return changed, key, device, device_id
end
