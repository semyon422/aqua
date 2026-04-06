local List = require("ui.base.List")
local View = require("ui.View")
local Box = require("ui.Box")

local test = {}

local FocusableView = View + {}
local CountingView = View + {}

function FocusableView:new(height)
	View.new(self)
	self.width = 100
	self.height = height or 20
	self.is_focusable = true
	self.handles_keyboard_input = true
	self.focus_events = {}
	self.keys = {}
end

function FocusableView:onFocus(e)
	table.insert(self.focus_events, "focus")
end

function FocusableView:onFocusLost(e)
	table.insert(self.focus_events, "blur")
end

function FocusableView:onKeyDown(e)
	table.insert(self.keys, e.key)
	if self.handle_key == e.key then
		return true
	end
	return false
end

function CountingView:new(height)
	View.new(self)
	self.width = 100
	self.height = height or 20
	self.layout_updates = 0
end

function CountingView:onLayoutUpdate()
	self.layout_updates = self.layout_updates + 1
end

---@param t testing.T
function test.focus_navigation_and_forwarding(t)
	local list = List()
	list:setSize(100, 60)

	local first = list:addView(FocusableView(20))
	local second = list:addView(FocusableView(20))
	local third = list:addView(FocusableView(20))

	list:onFocus({})

	t:eq(list.focused_index, 1)
	t:eq(first.focused, true)
	t:eq(second.focused, false)

	t:eq(list:onKeyDown({key = "down"}), true)
	t:eq(list.focused_index, 2)
	t:tdeq(first.focus_events, {"focus", "blur"})
	t:tdeq(second.focus_events, {"focus"})

	second.handle_key = "down"
	t:eq(list:onKeyDown({key = "down"}), true)
	t:eq(list.focused_index, 2)
	t:tdeq(second.keys, {"down"})

	t:eq(list:onKeyDown({key = "up"}), true)
	t:eq(list.focused_index, 1)
	t:tdeq(second.focus_events, {"focus", "blur"})
	t:eq(third.focused, false)
end

---@param t testing.T
function test.centered_scroll_target_is_clamped(t)
	local list = List()
	list.gap = 10
	list:setSize(100, 100)

	list:addView(FocusableView(40))
	list:addView(FocusableView(40))
	list:addView(FocusableView(40))

	list:onFocus({})
	t:eq(list.target_scroll_position, 0)

	list:focusChild(2)
	t:eq(list.target_scroll_position, 20)

	list:focusChild(3)
	t:eq(list.target_scroll_position, 40)
end

---@param t testing.T
function test.focus_loss_blurs_child(t)
	local list = List()
	list:setSize(100, 60)
	local child = list:addView(FocusableView(20))

	list:onFocus({})
	t:eq(child.focused, true)

	list:onFocusLost({})
	t:eq(child.focused, false)
	t:tdeq(child.focus_events, {"focus", "blur"})
end

---@param t testing.T
function test.scroll_updates_do_not_relayout_children(t)
	local list = List()
	list.box = Box()
	list.box:update(0, 0, 100, 60)
	list:setSize(100, 60)

	local first = list:addView(CountingView(20))
	local second = list:addView(CountingView(20))
	local third = list:addView(CountingView(20))

	list:refresh()
	local first_updates = first.layout_updates
	local second_updates = second.layout_updates
	local third_updates = third.layout_updates

	list:setTargetScrollPosition(10)
	list:update(0)

	t:eq(first.layout_updates, first_updates)
	t:eq(second.layout_updates, second_updates)
	t:eq(third.layout_updates, third_updates)
end

---@param t testing.T
function test.resize_relayouts_children_once(t)
	local list = List()
	list.box = Box()
	list.box:update(0, 0, 100, 60)
	list:setSizePercent(1, 1)

	local child = list:addView(CountingView(20))
	list:refresh()
	local initial_updates = child.layout_updates

	list.box:update(0, 0, 120, 80)
	list:applyLayout()
	t:eq(child.layout_updates, initial_updates + 1)
end

return test
