local just = require("just")
local theme = require("imgui.theme")
local gfx_util = require("gfx_util")

---@param id any
---@param text string
---@param w number
---@param h number
---@param selected boolean?
---@return number?
local function button(id, text, w, h, selected)
	local mx, my = love.graphics.inverseTransformPoint(love.mouse.getPosition())
	local over = 0 <= mx and mx <= w and 0 <= my and my <= h

	local changed, active, hovered = just.button(id, over)

	local rx, ry, rw, rh, rr = theme._rectangle(w, h)

	theme.setColor()
	love.graphics.rectangle("fill", 0, 0, rx, h)
	love.graphics.setColor(1, 1, 1, 1)
	if not selected then
		theme.setColor(active, hovered)
		love.graphics.rectangle("fill", rx, 0, rw, h)
		love.graphics.setColor(1, 1, 1, 0.66)
	end

	gfx_util.printFrame(text, 0, 0, w, h, "center", "center")

	just.next(w, h)

	return changed
end

return function(id, item, items, h, _h)
	id = tostring(id)

	local width = 0
	local font = love.graphics.getFont()
	for _, section in ipairs(items) do
		width = math.max(width, font:getWidth(section))
	end
	width = width + _h

	local newItem = item
	for _, _item in ipairs(items) do
		if button(id .. " tab " .. _item, _item, width, _h, _item == item) then
			newItem = _item
		end
	end

	theme.setColor()
	if h > _h * #items then
		local rx, ry, rw, rh, rr = theme._rectangle(width, _h)
		love.graphics.rectangle("fill", 0, 0, rx + rw, h - _h * #items)
	end

	return newItem, width
end
