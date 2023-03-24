local just = require("just")
local gfx_util = require("gfx_util")

return function(id, text, h)
	local font = love.graphics.getFont()
	local w = font:getWidth(text)

	just.mouse_over(id, just.is_over(w, h), "mouse")

	gfx_util.printFrame(text, 0, 0, w, h, "left", "center")

	just.next(w, h)

	return w, h
end
