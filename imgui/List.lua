local just = require("just")
local theme = require("imgui.theme")
local Container = require("imgui.Container")

local stack = {}

return function(id, w, h, _h, scrollY)
	if not id then
		w, h, _h = unpack(table.remove(stack))

		scrollY = Container()
		just.pop()

		love.graphics.setColor(1, 1, 1, 1)
		love.graphics.rectangle("line", theme._rectangle(w, h, _h))

		just.next(w, h)

		return scrollY
	end

	table.insert(stack, {w, h, _h})

	just.push()

	local x, y, _w, __h, r = theme._rectangle(w, h, _h)
	love.graphics.translate(x, y)
	Container(id, _w, __h, _h, scrollY)
end
