local just = require("just")
local theme = require("imgui.theme")
local Container = require("imgui.Container")

local stack = {}

return function(id, w, h, _w, _h, scrollY)
	if id then
		just.push()
		table.insert(stack, {w, h, _h})

		local x, y, __w, __h, r = theme._rectangle(w, h, _h)
		love.graphics.translate(x, y)

		Container(id, __w, __h, _w, _h, scrollY)
		return
	end

	w, h, _h = unpack(table.remove(stack))

	scrollY = Container()
	just.pop()

	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.rectangle("line", theme._rectangle(w, h, _h))

	just.next(w, h)

	return scrollY
end
