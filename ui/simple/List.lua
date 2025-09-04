local ScrollArea = require("ui.simple.ScrollArea")
local math_util = require("math_util")

---@class ui.Simple.List.Params
---@field panel_height number

---@class ui.Simple.List : ui.Simple.ScrollArea
---@overload fun(params: ui.Simple.List.Params): ui.Simple.List
local List = ScrollArea + {}

function List:load()
	ScrollArea.load(self)
	self:ensureExist("panel_height")
	self.item_count = 0
end

---@param items table
function List:setItems(items)
	self.items = items
	self.item_count = #items
	self.max_scroll = #items * self.panel_height
end

---@param index integer
---@return number
function List:getCenteredViewFrom(index)
	local items_in_view = math.ceil(self:getHeight() / self.panel_height) + 1
	return index * self.panel_height - (items_in_view / 2) * self.panel_height + self.panel_height / 4
end

---@param i integer
---@param center_view boolean?
function List:scrollToIndex(i, center_view)
	if center_view then
		self:scrollTo(self:getCenteredViewFrom(i))
	else
		self:scrollTo(i * self.panel_height)
	end
end

---@param i integer
---@param center_view boolean?
function List:teleportToIndex(i, center_view)
	self:resetScrollState()
	if center_view then
		self:setScrollPosition(self:getCenteredViewFrom(i))
	else
		self:setScrollPosition(i * self.panel_height)
	end
end

---@param i integer
function List:selectItem(i) end

---@return integer
function List:mousePositionToIndex()
	local _, imy = self.world_transform:inverseTransformPoint(0, love.mouse.getY())
	local top_index = self:getScrollPosition() / self.panel_height
	local relative_index = imy / self.panel_height
	return math_util.clamp(math.floor(top_index + relative_index) + 1, 1, self.item_count)
end

function List:update(dt)
	ScrollArea.update(self, dt)
	if not self.mouse_over then
		self.hover_index = nil
		return
	end

	self.hover_index = self:mousePositionToIndex()
end

---@param e ui.MouseClickEvent
function List:onMouseClick(e)
	self:scrollTo(self:getCenteredViewFrom(self.hover_index), true)
	self:selectItem(self.hover_index)
end

---@param item any
---@param i integer
---@param y number
function List:drawPanel(item, i, y) end

function List:draw()
	if self.item_count == 0 then
		return
	end

	local items_to_draw = math.ceil(self:getHeight() / self.panel_height) + 1

	local start_index = math.floor(self:getScrollPosition() / self.panel_height)
	start_index = math_util.clamp(start_index, 1, math.max(1, self.item_count - items_to_draw))

	local end_index = math.min(start_index + items_to_draw, self.item_count)

	love.graphics.translate(0, -self:getScrollPosition())
	for i = start_index, end_index do
		local y = (i - 1) * self.panel_height
		self:drawPanel(self.items[i], i, y)
	end
end

return List
