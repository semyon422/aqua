local just = require("just")
local ScrollBar = require("imgui.ScrollBar")

local stack = {}

return function(id, w, h, _w, _h, scrollY)
	if id then
		table.insert(stack, {id, w, h, _w, _h, scrollY, just.height})

		love.graphics.setColor(1, 1, 1, 1)
		just.clip(love.graphics.rectangle, "fill", 0, 0, w, h)

		local over = just.is_over(w, h)
		just.container(id, over)
		just.mouse_over(id, over, "mouse")
		love.graphics.translate(0, -scrollY)
		return
	end

	local height_start
	id, w, h, _w, _h, scrollY, height_start = unpack(table.remove(stack))

	just.container()
	local height = just.height - height_start
	just.clip()

	local over = just.is_over(w, h)
	local scroll = just.wheel_over(id, over)

	local overlap = math.max(height - h, 0)

	just.push()
	love.graphics.translate(w - _w, 0)
	local newScroll = ScrollBar(id .. "scrollbar", scrollY / overlap, _w, h, overlap / h)
	if newScroll then
		scrollY = overlap * newScroll
	end
	if overlap > 0 and scroll then
		scrollY = math.min(math.max(scrollY - scroll * _h, 0), overlap)
	end
	if overlap == 0 then
		scrollY = 0
	end
	just.pop()

	just.next(w, h)

	return scrollY
end
