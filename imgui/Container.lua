local just = require("just")
local ScrollBar = require("imgui.ScrollBar")

---@class imgui.ContainerState
---@field [1] any
---@field [2] number
---@field [3] number
---@field [4] number
---@field [5] number
---@field [6] number
---@field [7] number

---@type imgui.ContainerState[]
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
		table.insert(stack, {id, w, h, _w, _h, scrollY, just.height})

		love.graphics.setColor(1, 1, 1, 1)
		just.clip(love.graphics.rectangle, "fill", 0, 0, w, h)

		local over = just.is_over(w, h)
		just.container(id, over)
		just.mouse_over(id, over, "mouse")
		love.graphics.translate(0, -scrollY)
		return
	end

	---@type imgui.ContainerState
	local state = assert(table.remove(stack))
	local container_id = state[1]
	local container_w = state[2]
	local container_h = state[3]
	local scrollbar_w = state[4]
	local line_h = state[5]
	local container_scroll_y = state[6]
	local height_start = state[7]

	just.container()
	local height = just.height - height_start
	just.clip()

	local over = just.is_over(container_w, container_h)
	local scroll = just.wheel_over(container_id, over)

	local overlap = math.max(height - container_h, 0)

	just.push()
	love.graphics.translate(container_w - scrollbar_w, 0)
	local newScroll = ScrollBar(
		container_id .. "scrollbar",
		container_scroll_y / overlap,
		scrollbar_w,
		container_h,
		overlap / container_h
	)
	if newScroll then
		container_scroll_y = overlap * newScroll
	end
	if overlap > 0 and scroll then
		container_scroll_y = math.min(math.max(container_scroll_y - scroll * line_h, 0), overlap)
	end
	if overlap == 0 then
		container_scroll_y = 0
	end
	just.pop()

	just.next(container_w, container_h)

	return container_scroll_y
end
