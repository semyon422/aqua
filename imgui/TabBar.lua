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
	love.graphics.rectangle("fill", 0, 0, w, ry)
	love.graphics.setColor(1, 1, 1, 1)
	if not selected then
		theme.setColor(active, hovered)
		love.graphics.rectangle("fill", 0, ry, w, rh)
		love.graphics.setColor(1, 1, 1, 0.66)
	end

	gfx_util.printFrame(text, 0, 0, w, h, "center", "center")

	just.next(w, h)

	return changed
end

return function(id, item, items, w, h)
	id = tostring(id)

	just.row(true)

	local width = 0
	local font = love.graphics.getFont()
	for _, section in ipairs(items) do
		width = width + font:getWidth(section)
	end

	local newItem = item
	for _, _item in ipairs(items) do
		local _width = font:getWidth(_item) + (w - width) / #items
		if button(id .. " tab " .. _item, _item, _width, h, _item == item) then
			newItem = _item
		end
	end

	just.row()

	return newItem
end
