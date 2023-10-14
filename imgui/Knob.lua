local just = require("just")
local theme = require("imgui.theme")
local math_util = require("math_util")

local dragPosition
local baseValue

return function(id, value, h, drag_w)
	local over = just.is_over(h, h)

	local mx = love.graphics.inverseTransformPoint(love.mouse.getPosition())

	local pos = value
	if dragPosition then
		pos = baseValue + (mx - dragPosition) / drag_w
	end

	local new_value, active, hovered = just.slider(id, over, pos, value)

	if just.active_id == id and not dragPosition then
		new_value = nil
		dragPosition = mx
		baseValue = value
	elseif not just.active_id and dragPosition then
		dragPosition = nil
	end

	local circle_size = h * theme.size / 3

	local ang = math_util.map(value, 0, 1, math.pi / 2, math.pi / 2 + math.pi * 2)
	local R = h / 2 * theme.size - circle_size / 2
	local _x, _y = R * math.cos(ang) + h / 2, R * math.sin(ang) + h / 2
	local r = circle_size / 2 * 2 / 3

	theme.setColor(active, hovered)
	love.graphics.setLineWidth(circle_size)
	love.graphics.circle("line", h / 2, h / 2, R, 64)

	love.graphics.setColor(1, 1, 1, 1)

	love.graphics.setLineWidth(1)
	love.graphics.circle("fill", _x, _y, r, 64)
	love.graphics.circle("line", _x, _y, r, 64)

	just.next(h, h)

	return new_value
end
