local just = require("just")
local theme = require("imgui.theme")
local gfx_util = require("gfx_util")
local map = require("math_util").map

---@param w number
---@param h number
---@return number
local function getPosition(w, h)
	local x, y = love.graphics.inverseTransformPoint(love.mouse.getPosition())
	local value = map(x, h / 2, w - h / 2, 0, 1)
	return math.min(math.max(value, 0), 1)
end

return function(id, value, w, h, displayValue)
	local over = just.is_over(w, h)
	local pos = getPosition(w, h)

	local new_value, active, hovered = just.slider(id, over, pos, value)

	theme.setColor(active, hovered)
	theme.rectangle(w, h)

	local x = map(math.min(math.max(value, 0), 1), 0, 1, h / 2, w - h / 2)
	love.graphics.setColor(1, 1, 1, 1)
	theme.circle(h, x, h / 2)

	if displayValue then
		local width = love.graphics.getFont():getWidth(displayValue)
		local tx = (w - width) / 2
		if x >= w / 2 then
			tx = math.min(tx, x - h / 2 - width)
		else
			tx = math.max(tx, x + h / 2)
		end
		gfx_util.printFrame(displayValue, tx, 0, width, h, "left", "center")
	end

	just.next(w, h)

	return new_value
end
