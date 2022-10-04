local utf8 = require("utf8")

local just = {}

just.callbacks = {}

local mouse = {
	down = {},
	pressed = {},
	released = {},
	scroll_delta = 0,
	captured = false,
}

local keyboard = {
	down = {},
	pressed = {},
	released = {},
	text = "",
}

just.entered_id = nil
just.exited_id = nil

local focused_id = nil
just.focused_id = nil

local catched_id = nil
just.catched_id = nil

just.height = 0

local over_id

local hover_ids = {}
local next_hover_ids = {}

local keyboard_stack = {}
local next_keyboard_stack = {}

local containers = {}
local container_overs = {}
local zindexes = {}
local last_zindex = 0

local line_c = 0
local line_h = 0
local line_w = 0

local is_row = false
local is_sameline = false

local line_stack = {}

function just.push(...)
	love.graphics.push(...)
	table.insert(line_stack, {
		c = line_c,
		h = line_h,
		w = line_w,
		is_row = is_row,
		is_sameline = is_sameline,
		height = just.height,
	})
end

function just.pop()
	love.graphics.pop()
	local state = table.remove(line_stack)
	line_c = state.c
	line_h = state.h
	line_w = state.w
	is_row = state.is_row
	is_sameline = state.is_sameline
	just.height = state.height
end

function just.focus(id)
	focused_id = id
end

function just.catch(id)
	local catched = catched_id == just.catched_id
	catched_id = id
	return catched
end

function just.is_over(w, h)
	local mx, my = love.graphics.inverseTransformPoint(love.mouse.getPosition())
	local x, y = 0, 0
	if w < 0 then
		x, w = w, x
	end
	if h < 0 then
		y, h = h, y
	end
	return x <= mx and mx <= w and y <= my and my <= h
end

function just.row(state)
	is_row = false
	just.next()
	is_row = state
end

function just.next(w, h)
	w, h = w or 0, h or 0
	line_w = line_c + w
	line_h = line_c > 0 and math.max(line_h, h) or h
	is_sameline = false
	if is_row then
		love.graphics.translate(w, 0)
		line_c = line_w
	else
		love.graphics.translate(-line_c, line_h)
		line_c = 0
		just.height = just.height + line_h
	end
end

function just.sameline()
	assert(not is_row, "just.sameline() can not be called in a row mode")
	assert(not is_sameline, "just.sameline() called twice")
	is_sameline = true
	line_c = line_w
	love.graphics.translate(line_c, -line_h)
	just.height = just.height - line_h
end

function just.emptyline(h)
	just.next(0, h)
end

function just.indent(w)
	if line_c == 0 then
		line_h = 0
	end
	just.next(w, line_h)
	if not is_row then
		just.sameline()
	end
end

function just.offset(w)
	if not w then
		return line_w
	end
	just.indent(w - line_w)
end

function just.text(text, limit, right)
	local _limit = limit or math.huge
	assert(not right or _limit ~= math.huge)
	local font = love.graphics.getFont()
	love.graphics.printf(text, 0, 0, _limit, right and "right" or "left")
	local w, wrapped = font:getWrap(text, _limit)
	local h = font:getHeight() * font:getLineHeight() * #wrapped
	just.next(limit or w, h)
	return limit or w, h
end

local push_stencil, pop_stencil, stencilfunction
do
	local stack = {}
	local sf, q, w, e, r, t, y, u, i
	function push_stencil(_sf, ...)
		if sf then
			table.insert(stack, {sf, q, w, e, r, t, y, u, i})
		end
		sf, q, w, e, r, t, y, u, i = _sf, ...
		return #stack
	end
	function pop_stencil()
		local s = table.remove(stack)
		if not s then
			sf = nil
			return
		end
		sf, q, w, e, r, t, y, u, i = unpack(s, 1, 9)
	end
	function stencilfunction()
		return sf(q, w, e, r, t, y, u, i)
	end
end
function just.clip(sf, ...)
	if not sf then
		just.pop()
		love.graphics.stencil(stencilfunction, "decrement", 1, true)
		return pop_stencil()
	end
	just.push("all")
	local layer = push_stencil(sf, ...)
	local action = layer == 0 and "replace" or "increment"
	love.graphics.stencil(stencilfunction, action, 1, true)
	love.graphics.setStencilTest("greater", layer)
end

local function clear_table(t)
	for k in pairs(t) do
		t[k] = nil
	end
end

function just._end()
	assert(#containers == 0, "container not closed")

	if not zindexes[focused_id] then
		just.focus()
	end
	just.focused_id = focused_id

	clear_table(mouse.pressed)
	clear_table(mouse.released)
	clear_table(keyboard.pressed)
	clear_table(keyboard.released)
	clear_table(zindexes)

	local any_mouse_over = next_hover_ids.mouse or next_hover_ids.wheel

	just.entered_id, just.exited_id = nil, nil
	catched_id, just.catched_id = nil, nil
	just.height = 0
	last_zindex = 0
	line_c = 0
	mouse.scroll_delta = 0
	mouse.captured = any_mouse_over or just.active_id

	keyboard.text = ""

	clear_table(hover_ids)
	hover_ids, next_hover_ids = next_hover_ids, hover_ids

	clear_table(keyboard_stack)
	keyboard_stack, next_keyboard_stack = next_keyboard_stack, keyboard_stack

	local new_over_id = hover_ids.mouse
	if over_id ~= new_over_id then
		just.exited_id = over_id
		over_id = new_over_id
		just.entered_id = new_over_id
	end
end

function just.callbacks.mousepressed(_, _, button)
	mouse.down[button] = true
	mouse.pressed[button] = true
	return mouse.captured
end

function just.callbacks.mousereleased(_, _, button)
	mouse.down[button] = nil
	mouse.released[button] = true
	return mouse.captured
end

function just.callbacks.mousemoved()
	return mouse.captured
end

function just.callbacks.wheelmoved(_, y)
	mouse.scroll_delta = y
	return mouse.captured
end

function just.callbacks.keypressed(_, scancode, _)
	keyboard.down[scancode] = true
	keyboard.pressed[scancode] = true
end

function just.callbacks.keyreleased(_, scancode, _)
	keyboard.down[scancode] = nil
	keyboard.released[scancode] = true
end

function just.callbacks.textinput(text)
	keyboard.text = keyboard.text .. text
end

function just.is_container_over(depth)
	local index = #container_overs - (depth or 1) + 1
	return #container_overs == 0 or container_overs[index]
end

function just.container_id()
	return containers[#containers]
end

function just.mouse_over(id, over, group, new_zindex)
	if not id then return end
	assert(group, "missing group")
	if not zindexes[id] or new_zindex then
		last_zindex = last_zindex + 1
		zindexes[id] = last_zindex
	end

	if catched_id == id then
		just.catched_id = id
	end

	local container_over = just.is_container_over()

	local next_hover_id = next_hover_ids[group]
	if over and container_over and (not next_hover_id or zindexes[id] > zindexes[next_hover_id]) then
		next_hover_ids[group] = id
	end

	return container_over and id == hover_ids[group]
end

function just.wheel_over(id, over)
	local d = mouse.scroll_delta
	return just.mouse_over(id, over, "wheel") and d ~= 0 and d
end

function just.keyboard_over()
	local layer = #containers
	if layer == 0 then
		return true
	end

	local id = containers[layer]
	if next_keyboard_stack[layer] ~= id then
		next_keyboard_stack[layer] = id
		for i = layer + 1, #next_keyboard_stack do
			next_keyboard_stack[i] = nil
		end
	end

	return keyboard_stack[layer] == id
end

function just.button(id, over, button)
	if not id then return end
	over = just.mouse_over(id, over, "mouse")
	button = button or next(mouse.pressed) or next(mouse.released) or next(mouse.down)
	if mouse.pressed[button] and over then
		just.active_id = id
	end

	local same_id = just.active_id == id

	local down = mouse.down[button]
	local active = over and same_id and down
	local hovered = over and (same_id or not down)

	local changed
	if same_id and not down then
		changed = over and same_id and button
		just.active_id = nil
	end

	return changed, active, hovered
end

function just.slider(id, over, pos, value)
	if not id then return end
	local _, active, hovered = just.button(id, over)

	local new_value = value
	if just.active_id == id then
		new_value = pos
	end

	return value ~= new_value and new_value, active, hovered
end

function just.container(id, over)
	if not id then
		table.remove(container_overs)
		return table.remove(containers)
	end

	table.insert(containers, id)
	table.insert(container_overs, over)
end

function just.keypressed(scancode, unset)
	local res = just.keyboard_over() and keyboard.pressed[scancode]
	if res and unset then
		keyboard.pressed[scancode] = nil
	end
	return res
end

function just.keyreleased(scancode, unset)
	local res = just.keyboard_over() and keyboard.released[scancode]
	if res and unset then
		keyboard.released[scancode] = nil
	end
	return res
end

local function text_split(text, index)
	local _index = utf8.offset(text, index) or 1
	return text:sub(1, _index - 1), text:sub(_index)
end

local function text_remove(text, index, forward)
	local _
	local left, right = text_split(text, index)

	if forward then
		_, right = text_split(right, 2)
	else
		left, _ = text_split(left, utf8.len(left))
		index = math.max(1, index - 1)
	end

	return left .. right, index
end

function just.textinput(text, index)
	text = tostring(text)
	index = index or utf8.len(text) + 1

	if not just.keyboard_over() then
		return false, text, index, text_split(text, index)
	end

	local bt, bi = text, index

	local _text = keyboard.text
	if _text ~= "" then
		local left, right = text_split(text, index)
		text = left .. _text .. right
		index = index + utf8.len(_text)
	end

	local pressed = keyboard.pressed
	if pressed.left then
		index = index - 1
	elseif pressed.right then
		index = index + 1
	elseif pressed.backspace then
		text, index = text_remove(text, index)
	elseif pressed.delete then
		text, index = text_remove(text, index, true)
	elseif pressed.home then
		index = 1
	elseif pressed["end"] then
		index = utf8.len(text)
	end

	local changed = text ~= bt and "text" or index ~= bi and "index"
	index = math.min(math.max(index, 1), utf8.len(text) + 1)

	return changed, text, index, text_split(text, index)
end

return just
