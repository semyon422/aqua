local just = require("just")
local theme = require("imgui.theme")

---@param id any
---@param image love.Image
---@param size number
---@param scale number
---@return number?
return function(id, image, size, scale)
	local width = image:getWidth()

	local mx, my = love.graphics.inverseTransformPoint(love.mouse.getPosition())
	local over = 0 <= mx and mx <= size and 0 <= my and my <= size

	local changed, active, hovered = just.button(id, over)
	theme.setColorBoundless(active, hovered)
	love.graphics.rectangle("fill", 0, 0, size, size)

	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.draw(image, size * (1 - scale) / 2, size * (1 - scale) / 2, 0, size / width * scale)

	just.next(size, size)

	return changed
end
