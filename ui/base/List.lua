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

function List:new()
	View.new(self)
	self.views = {}
	self.gap = 0
	self.target_scroll_position = 0
	self.scroll_position = 0
	self.focused_index = nil
	self.content_height = 0
	self.content_box = Box()
	self.item_offsets = {}
	self.first_visible = 1
	self.last_visible = 0
	self.layout_dirty = true
	self.visible_layout_dirty = true
	self.handles_keyboard_input = true
	self.is_focusable = true
end

function List:invalidateLayout()
	self.layout_dirty = true
	self.visible_layout_dirty = true
end

function List:invalidateVisibleLayout()
	self.visible_layout_dirty = true
end

---@param position number
function List:onTargetScrollPositionClamped(position) end

---@param position number
function List:onScrollPositionClamped(position) end

---@return number
function List:getChildBaseX()
	return 0
end

---@return number
function List:getChildBaseY()
	return 0
end

---@return number
function List:getTrailingInset()
	return 0
end

---@return number
function List:getContentBoxWidth()
	return self.width
end

---@return number
function List:getContentBoxHeight()
	return self.height
end

---@return number
---@return number
function List:getViewportRange()
	return 0, self.height
end

---@return number
---@return number
function List:getChildPosition(index)
	return self:getChildBaseX(), (self.item_offsets[index] or 0) - self.scroll_position
end

---@protected
function List:ensureLayout()
	if not self.box then
		return
	end

	if self.layout_dirty then
		self:applyLayout()
	end
end

---@private
---@param position number?
---@return number
function List:clampScrollPosition(position)
	local max_scroll = math.max(0, self.content_height - self.height)
	return math.max(0, math.min(position or 0, max_scroll))
end

---@private
---@return number
function List:measureContentHeight()
	local content_y = self:getChildBaseY()
	local trailing_inset = self:getTrailingInset()
	local content_height = content_y + trailing_inset

	for i, view in ipairs(self.views) do
		content_height = math.max(content_height, content_y + view:getHeight() + trailing_inset)
		content_y = content_y + view.height
		if i < #self.views then
			content_y = content_y + self.gap
		end
	end

	return math.max(0, content_height)
end

---@param start_index integer
---@param end_index integer
function List:updateVisibleChildTransforms(start_index, end_index)
	for i = start_index, end_index do
		local view = self.views[i]
		if view then
			local x, y = self:getChildPosition(i)
			view.x = x
			view.y = y
			view:updateTransform()
		end
	end
end

---@private
---@param viewport_top number
---@return integer
function List:findFirstVisibleIndex(viewport_top)
	local low = 1
	local high = #self.views
	local result = #self.views + 1

	while low <= high do
		local mid = math.floor((low + high) / 2)
		local view = self.views[mid]
		local top = self.item_offsets[mid] or 0
		if top + view.height > viewport_top then
			result = mid
			high = mid - 1
		else
			low = mid + 1
		end
	end

	return result
end

---@private
---@param viewport_bottom number
---@return integer
function List:findLastVisibleIndex(viewport_bottom)
	local low = 1
	local high = #self.views
	local result = 0

	while low <= high do
		local mid = math.floor((low + high) / 2)
		local top = self.item_offsets[mid] or 0
		if top < viewport_bottom then
			result = mid
			low = mid + 1
		else
			high = mid - 1
		end
	end

	return result
end

---@protected
function List:refreshVisibleLayout()
	local viewport_top, viewport_bottom = self:getViewportRange()
	local first_visible = self:findFirstVisibleIndex(viewport_top + self.scroll_position)
	local last_visible = self:findLastVisibleIndex(viewport_bottom + self.scroll_position)

	if first_visible > last_visible then
		self.first_visible = 1
		self.last_visible = 0
		self.visible_layout_dirty = false
		return
	end

	self.first_visible = first_visible
	self.last_visible = last_visible
	self:updateVisibleChildTransforms(first_visible, last_visible)
	self.visible_layout_dirty = false
end

---@protected
function List:ensureVisibleLayout()
	self:ensureLayout()
	if self.visible_layout_dirty then
		self:refreshVisibleLayout()
	end
end

---@generic T: ui.View
---@param view T
---@return T
function List:addView(view)
	table.insert(self.views, view)
	self:invalidateLayout()
	if self.box then
		self:applyLayout()
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

	self:invalidateLayout()

	if self.box then
		self:applyLayout()
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
	table_util.clear(self.item_offsets)
	self.focused_index = nil
	self.content_height = 0
	self:setTargetScrollPosition(0)
	self.scroll_position = 0
	self.first_visible = 1
	self.last_visible = 0
	self:invalidateLayout()
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
	if self.box and self.layout_dirty then
		self:ensureLayout()
	elseif not self.box then
		self.content_height = self:measureContentHeight()
	end

	position = self:clampScrollPosition(position)

	if self.target_scroll_position == position then
		return false
	end

	self.target_scroll_position = position
	self:invalidateVisibleLayout()
	return true
end

function List:ensureFocusedChildVisible()
	if self.box then
		self:ensureLayout()
	end

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
	if self.box then
		self:ensureLayout()
	end

	if self.item_offsets[index] ~= nil then
		return self.item_offsets[index]
	end

	local y = self:getChildBaseY()
	for i = 1, index - 1 do
		local view = self.views[i]
		if not view then
			break
		end
		y = y + view.height + self.gap
	end

	return y
end

function List:applyLayout()
	assert(self.box, "ui.List:applyLayout() requires self.box")
	View.applyLayout(self)

	self.content_box.x = self:getChildBaseX()
	self.content_box.y = self:getChildBaseY()
	self.content_box.width = math.max(0, self:getContentBoxWidth())
	self.content_box.height = math.max(0, self:getContentBoxHeight())
	self.content_box.transform:reset()
	self.content_box.transform:apply(self.transform)

	local child_x = self:getChildBaseX()
	local content_y = self:getChildBaseY()
	local trailing_inset = self:getTrailingInset()
	local content_height = content_y + trailing_inset

	for i, view in ipairs(self.views) do
		view.box = self.content_box
		view.ui_scale = self.ui_scale
		view.x = child_x
		view.y = content_y - self.scroll_position
		view:applyLayout()
		self.item_offsets[i] = content_y
		content_height = math.max(content_height, content_y + view:getHeight() + trailing_inset)

		content_y = content_y + view.height
		if i < #self.views then
			content_y = content_y + self.gap
		end
	end

	self.content_height = math.max(0, content_height)
	local clamped_target_scroll_position = self:clampScrollPosition(self.target_scroll_position)
	if clamped_target_scroll_position ~= self.target_scroll_position then
		self.target_scroll_position = clamped_target_scroll_position
		self:onTargetScrollPositionClamped(clamped_target_scroll_position)
	end

	local clamped_scroll_position = self:clampScrollPosition(self.scroll_position)
	if clamped_scroll_position ~= self.scroll_position then
		self.scroll_position = clamped_scroll_position
		self:onScrollPositionClamped(clamped_scroll_position)
	end

	self.layout_dirty = false
	self.visible_layout_dirty = true
	self:refreshVisibleLayout()
end

function List:refresh()
	self:applyLayout()
end

function List:updateTransform()
	View.updateTransform(self)
	self.content_box.transform:reset()
	self.content_box.transform:apply(self.transform)

	if self.first_visible <= self.last_visible then
		self:updateVisibleChildTransforms(self.first_visible, self.last_visible)
	end
end

---@param dt number
function List:update(dt)
	self:ensureVisibleLayout()

	if self.scroll_position ~= self.target_scroll_position then
		self.scroll_position = self.target_scroll_position
		self:invalidateVisibleLayout()
		self:refreshVisibleLayout()
	end

	for i = self.first_visible, self.last_visible do
		local view = self.views[i]
		if view then
			view:update(dt)
		end
	end
end

---@param inputs ui.Inputs
function List:acceptInputs(inputs)
	self:ensureVisibleLayout()

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
	self:ensureVisibleLayout()

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
