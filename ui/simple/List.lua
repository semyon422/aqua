local ScrollArea = require("ui.simple.ScrollArea")
local math_util = require("math_util")

---@class ui.Simple.List : ui.Simple.ScrollArea
---@operator call: ui.Simple.List
local List = ScrollArea + {}

function List:load()
	ScrollArea.load(self)
	self.panel_height = 60
	self.item_count = 0
end

---@param items table
function List:setItems(items)
	self.items = items
	self.item_count = #items
	self.max_scroll = #items * self.panel_height
end

---@param i integer
function List:scrollToIndex(i)
	self:scrollTo(i * self.panel_height)
end

---@param i integer
function List:selectItem(i) end

---@return integer
function List:mousePositionToIndex()
	local _, imy = love.graphics.inverseTransformPoint(0, love.mouse.getY())
	local top_index = self:getScrollPosition() / self.panel_height
	local relative_index = imy / self.panel_height
	return math.floor(top_index + relative_index) + 1
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
	local items_to_draw = math.ceil(self:getHeight() / self.panel_height) + 1
	self:scrollTo(self.hover_index * self.panel_height - (items_to_draw / 2) * self.panel_height)
	self:selectItem(self.hover_index)
end

---@param item any
---@param i integer
---@param y number
function List:drawPanel(item, i, y)
	love.graphics.setColor(0.1, 0.1, 0.1)
	love.graphics.rectangle("fill", 0, y, self:getWidth(), self.panel_height)
end

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
