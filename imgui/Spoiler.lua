local just = require("just")
local theme = require("imgui.theme")
local gfx_util = require("gfx_util")

local height = 0
local height_start = 0
local base_height = 0
local width = 0
local open_frame_id

return function(id, w, h, preview)
	if id then
		base_height = h
		width = w

		local changed, active, hovered = just.button(id, just.is_over(w, h))
		if just.focused_id ~= id and changed then
			just.focus(id)
			open_frame_id = id
		end
		if just.focused_id ~= id or open_frame_id == id then
			theme.setColor(active, hovered)
			theme.rectangle(w, h)

			love.graphics.setColor(1, 1, 1, 1)
			gfx_util.printFrame(tostring(preview), 0, 0, w, h, "center", "center")

			if open_frame_id == id then
				just.clip(love.graphics.rectangle, "fill", 0, 0, 0, 0)
				return true
			end
			just.next(w, h)
			return
		end

		height_start = just.height

		love.graphics.setColor(1, 1, 1, 1)
		local x, y, _w, _h, r = theme._rectangle(w, h)
		just.clip(love.graphics.rectangle, "fill", x, y, _w, height, r)

		local over = just.is_over(width, height)
		just.container(id, over)
		just.mouse_over(id, over, "mouse")

		love.graphics.translate(x, y)

		return true
	end

	height = just.height - height_start
	just.container()
	just.clip()

	h = base_height
	if open_frame_id then
		just.next(width, h)
		open_frame_id = nil
		return
	end

	local x, y, _w, _h, r = theme._rectangle(width, h)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.rectangle("line", x, y, _w, height, r)
	just.next(width, height + x * 2)
end
