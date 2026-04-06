local Box = require("ui.Box")
local View = require("ui.View")
local table_util = require("table_util")

---@class ui.List : ui.View
---@operator call: ui.List
---@field views ui.View[]
---@field gap number
---@field target_scroll_position number
---@field scroll_position number
---@field focused_index integer?
---@field content_height number
---@field content_box ui.Box
---@field first_visible integer
---@field last_visible integer
local List = View + {}

local function resolve_percent_size(view)
	if view.width_percent ~= nil then
		assert(view.box, "ui.List:refresh() child requires box")
		view.width = view.box.width * view.width_percent
	end
	if view.height_percent ~= nil then
		assert(view.box, "ui.List:refresh() child requires box")
		view.height = view.box.height * view.height_percent
	end
end

---@param view ui.View
---@param box ui.Box
---@param ui_scale number
local function refresh_child_view(view, box, ui_scale)
	view.box = box
	view.ui_scale = ui_scale
	view:refresh()
end

function List:new()
	View.new(self)
	self.views = {}
	self.gap = 0
	self.target_scroll_position = 0
	self.scroll_position = 0
	self.focused_index = nil
	self.content_height = 0
	self.content_box = Box()
	self.first_visible = 1
	self.last_visible = 0
	self.handles_keyboard_input = true
	self.is_focusable = true
end

---@generic T: ui.View
---@param view T
---@return T
function List:addView(view)
	table.insert(self.views, view)
	if self.box then
		self:refresh()
	end
	return view
end

---@param view ui.View
---@return boolean removed
function List:removeView(view)
	local index = table_util.indexof(self.views, view)
	if not index then
		return false
	end

	local was_focused = self.focused_index == index
	table.remove(self.views, index)

	if self.focused_index and self.focused_index > index then
		self.focused_index = self.focused_index - 1
	elseif was_focused then
		self.focused_index = nil
	end

	if self.box then
		self:refresh()
	end

	if was_focused then
		self:focusChild(index)
	end

	return true
end

function List:clearViews()
	if self.focused_index then
		self:blurFocusedChild()
	end

	table_util.clear(self.views)
	self.focused_index = nil
	self.content_height = 0
	self:setTargetScrollPosition(0)
	self.scroll_position = 0
end

---@return integer?
function List:getFirstFocusableIndex()
	for i, view in ipairs(self.views) do
		if view.is_focusable then
			return i
		end
	end
end

---@param start_index integer?
---@param direction integer
---@return integer?
function List:getNextFocusableIndex(start_index, direction)
	if direction == 0 then
		return start_index
	end

	local index = start_index or (direction > 0 and 0 or (#self.views + 1))
	index = index + direction

	while index >= 1 and index <= #self.views do
		local view = self.views[index]
		if view.is_focusable then
			return index
		end
		index = index + direction
	end
end

---@param child ui.View
---@param event table
local function focus_child(child, event)
	if child.focused then
		return
	end
	child.focused = true
	child:onFocus(event)
end

---@param child ui.View
---@param event table
local function blur_child(child, event)
	if not child.focused then
		return
	end
	child.focused = false
	child:onFocusLost(event)
end

function List:blurFocusedChild()
	local child = self.focused_index and self.views[self.focused_index]
	if not child then
		self.focused_index = nil
		return
	end

	blur_child(child, {target = child})
end

---@param index integer?
---@return boolean changed
function List:focusChild(index)
	if index ~= nil then
		local view = self.views[index]
		if not view or not view.is_focusable then
			return false
		end
	end

	if self.focused_index == index then
		if index then
			self:ensureFocusedChildVisible()
		end
		return false
	end

	local previous_index = self.focused_index
	local previous_child = previous_index and self.views[previous_index]
	local child = index and self.views[index]

	self.focused_index = index

	if previous_child then
		blur_child(previous_child, {target = previous_child, next_focused = child})
	end

	if child then
		focus_child(child, {target = child, previously_focused = previous_child})
	end

	if child then
		self:ensureFocusedChildVisible()
	end

	return true
end

---@return boolean changed
function List:focusNext()
	return self:focusChild(self:getNextFocusableIndex(self.focused_index, 1))
end

---@return boolean changed
function List:focusPrevious()
	return self:focusChild(self:getNextFocusableIndex(self.focused_index, -1))
end

---@param position number
---@return boolean changed
function List:setTargetScrollPosition(position)
	local max_scroll = math.max(0, self.content_height - self.height)
	position = math.max(0, math.min(position or 0, max_scroll))

	if self.target_scroll_position == position then
		return false
	end

	self.target_scroll_position = position
	return true
end

function List:ensureFocusedChildVisible()
	local child = self.focused_index and self.views[self.focused_index]
	if not child then
		self:setTargetScrollPosition(0)
		return
	end

	local center = self:getItemOffset(self.focused_index) + child.height * 0.5
	self:setTargetScrollPosition(center - self.height * 0.5)
end

---@param index integer
---@return number
function List:getItemOffset(index)
	local y = 0

	for i = 1, index - 1 do
		local view = self.views[i]
		y = y + view.height + self.gap
	end

	return y
end

function List:refresh()
	assert(self.box, "ui.List:refresh() requires self.box")
	resolve_percent_size(self)

	self.content_box.width = self.width
	self.content_box.height = self.height
	View.updateTransform(self)
	self.content_box.transform:reset()
	self.content_box.transform:apply(self.transform)

	local viewport_height = self.height
	local scroll_position = self.scroll_position
	local y = -scroll_position
	local content_y = 0
	local content_height = 0

	self.first_visible = #self.views + 1
	self.last_visible = 0

	for i, view in ipairs(self.views) do
		view.x = 0
		view.y = y
		refresh_child_view(view, self.content_box, self.ui_scale)

		local is_visible = y + view.height > 0 and y < viewport_height
		if is_visible then
			self.first_visible = math.min(self.first_visible, i)
			self.last_visible = math.max(self.last_visible, i)
		end

		content_height = math.max(content_height, content_y + view:getHeight())

		y = y + view.height
		content_y = content_y + view.height
		if i < #self.views then
			y = y + self.gap
			content_y = content_y + self.gap
		end
	end

	if self.last_visible == 0 then
		self.first_visible = 1
	end

	self.content_height = math.max(0, content_height)
	self:setTargetScrollPosition(self.target_scroll_position)

	local clamped_scroll_position = math.max(0, math.min(self.scroll_position, math.max(0, self.content_height - self.height)))
	if clamped_scroll_position ~= self.scroll_position then
		self.scroll_position = clamped_scroll_position
		self:refresh()
	end
end

function List:updateTransform()
	View.updateTransform(self)
	self.content_box.transform:reset()
	self.content_box.transform:apply(self.transform)

	for _, view in ipairs(self.views) do
		if view.box then
			view:updateTransform()
		end
	end
end

---@param dt number
function List:update(dt)
	if self.scroll_position ~= self.target_scroll_position then
		self.scroll_position = self.target_scroll_position
		self:refresh()
	end

	for i = self.first_visible, self.last_visible do
		local view = self.views[i]
		if view then
			view:tick(dt)
		end
	end
end

---@param inputs ui.Inputs
function List:acceptInputs(inputs)
	for i = self.last_visible, self.first_visible, -1 do
		local view = self.views[i]
		if view then
			local handles_keyboard_input = view.handles_keyboard_input
			view.handles_keyboard_input = false
			view:acceptInputs(inputs)
			view.handles_keyboard_input = handles_keyboard_input
		end
	end

	inputs:processView(self)
end

---@param e ui.FocusEvent
function List:onFocus(e)
	self.focused = true

	local index = self.focused_index or self:getFirstFocusableIndex()
	if index then
		self:focusChild(index)
	end
end

---@param e ui.FocusLostEvent
function List:onFocusLost(e)
	self.focused = false
	self:blurFocusedChild()
end

---@param e ui.KeyDownEvent
---@return boolean handled
function List:onKeyDown(e)
	local child = self.focused_index and self.views[self.focused_index]
	if child then
		local handled = child:onKeyDown(e)
		if handled then
			return true
		end
	end

	if e.key == "up" then
		return self:focusPrevious()
	end

	if e.key == "down" then
		return self:focusNext()
	end

	return false
end

function List:draw()
	love.graphics.push("all")

	local x1, y1 = self.transform:transformPoint(0, 0)
	local x2, y2 = self.transform:transformPoint(self.width, self.height)

	local left = math.min(x1, x2)
	local top = math.min(y1, y2)
	local right = math.max(x1, x2)
	local bottom = math.max(y1, y2)

	love.graphics.intersectScissor(
		math.floor(left + 0.5),
		math.floor(top + 0.5),
		math.max(0, math.floor(right - left + 0.5)),
		math.max(0, math.floor(bottom - top + 0.5))
	)

	for i = self.first_visible, self.last_visible do
		local view = self.views[i]
		if view then
			love.graphics.push("all")
			love.graphics.origin()
			love.graphics.applyTransform(view.transform)
			view:draw()
			love.graphics.pop()
		end
	end

	love.graphics.pop()
end

return List
