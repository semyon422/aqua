local just = require("just")
local theme = require("imgui.theme")
local Container = require("imgui.Container")

---@class imgui.ListState
---@field [1] number
---@field [2] number
---@field [3] number

---@type imgui.ListState[]
local stack = {}

---@param id any?
---@param w number?
---@param h number?
---@param _w number?
---@param _h number?
---@param scrollY number?
---@return number?
return function(id, w, h, _w, _h, scrollY)
	if id then
		assert(w and h and _w and _h and scrollY)
		just.push()
		table.insert(stack, {w, h, _h})

		local x, y, __w, __h, r = theme._rectangle(w, h, _h)
		love.graphics.translate(x, y)

		Container(id, __w, __h, _w, _h, scrollY)
		return
	end

	---@type imgui.ListState
	local state = assert(table.remove(stack))
	local list_w = state[1]
	local list_h = state[2]
	local line_h = state[3]

	local list_scroll_y = Container()
	just.pop()

	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.rectangle("line", theme._rectangle(list_w, list_h, line_h))

	just.next(list_w, list_h)

	return list_scroll_y
end
