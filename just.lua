local utf8 = require("utf8")
local math_util = require("math_util")

local just = {}

just.callbacks = {}

local mouse, keyinput
local focused_id, catched_id, over_id
local hover_ids, next_hover_ids
local key_stack, next_key_stack
local containers, container_overs
local zindexes, last_zindex
local line_c, line_h, line_w
local is_row, is_sameline
local line_stack
local textinput
local selection

local devices = {"key", "gamepad", "joystick", "midi"}
local device_arg_index = {2, 2, 2, 1}

---@return table
local function new_keyinput()
	return {
		down = {},
		pressed = {},
		released = {},
	}
end

function just.reset()
	mouse = {
		down = {},
		pressed = {},
		released = {},
		scroll_delta = 0,
		captured = false,
	}

	keyinput = {}
	for _, device in ipairs(devices) do
		keyinput[device] = new_keyinput()
	end

	textinput = ""

	just.entered_id = nil
	just.exited_id = nil

	focused_id = nil
	just.focused_id = nil

	catched_id = nil
	just.catched_id = nil

	just.height = 0

	over_id = nil

	hover_ids, next_hover_ids = {}, {}
	key_stack, next_key_stack = {}, {}

	containers, container_overs = {}, {}
	zindexes = {}
	last_zindex = 0

	just.origin()

	line_stack = {}
	just.clip("reset")
end

---@param ... string?
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

function just.origin()
	line_c, line_h, line_w = 0, 0, 0
	is_row = false
	is_sameline = false
end

---@param id any?
function just.focus(id)
	focused_id = id
end

---@param id any?
---@return any|nil
function just.catch(id)
	local catched = rawequal(catched_id, just.catched_id)
	catched_id = id
	return catched
end

---@param w number
---@param h number
---@param x number?
---@param y number?
---@return boolean
function just.is_over(w, h, x, y)
	local mx, my = love.graphics.inverseTransformPoint(love.mouse.getPosition())
	x, y = x or 0, y or 0
	if w < 0 then
		x, w = x + w, -w
	end
	if h < 0 then
		y, h = y + h, -h
	end
	return x <= mx and mx < x + w and y <= my and my < y + h
end

---@param a_x number?
---@param a_y number?
---@param b_x number?
---@param b_y number?
function just.select(a_x, a_y, b_x, b_y)
	if not a_x then
		selection = nil
		return
	end
	a_x, a_y = a_x or 0, a_y or 0
	selection = selection or {}
	local s = selection
	s[1], s[2] = love.graphics.transformPoint(a_x, a_y)
	s[3], s[4] = love.graphics.transformPoint(b_x, a_y)
	s[5], s[6] = love.graphics.transformPoint(b_x, b_y)
	s[7], s[8] = love.graphics.transformPoint(a_x, b_y)
	math_util.lmap(s, math.floor)
end

local selectable = {}

---@param w number
---@param h number
---@param x number?
---@param y number?
---@return boolean
function just.is_selected(w, h, x, y)
	if not selection then
		return false
	end
	x, y = x or 0, y or 0
	local c = selectable
	c[1], c[2] = love.graphics.transformPoint(x, y)
	c[3], c[4] = love.graphics.transformPoint(x + w, y)
	c[5], c[6] = love.graphics.transformPoint(x + w, y + h)
	c[7], c[8] = love.graphics.transformPoint(x, y + h)
	math_util.lmap(c, math.floor)
	return math_util.intersect2(selection, c)
end

---@param state boolean?
function just.row(state)
	is_row = false
	just.next()
	is_row = state
end

---@param w number?
---@param h number?
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
	if is_sameline or is_row then return end
	is_sameline = true
	line_c = line_w
	love.graphics.translate(line_c, -line_h)
	just.height = just.height - line_h
end

---@param h number
function just.emptyline(h)
	just.next(0, h)
end

---@param w number
function just.indent(w)
	if line_c == 0 then
		line_h = 0
	end
	just.next(w, line_h)
	if not is_row then
		just.sameline()
	end
end

---@param w number?
---@return number?
function just.offset(w)
	if not w then
		return line_w
	end
	just.indent(w - line_w)
end

---@param text string
---@param limit number?
---@param right boolean?
---@return number
---@return number
function just.text(text, limit, right)
	local _limit = limit or math.huge
	assert(not right or _limit ~= math.huge)
	local font = love.graphics.getFont()
	love.graphics.printf(text, 0, 0, _limit, right and "right" or "left")
	local w = font:getWidth(text)
	local h = font:getHeight() * font:getLineHeight() * #select(2, font:getWrap(text, _limit))
	just.next(limit or w, h)
	return limit or w, h
end

local push_stencil, pop_stencil, reset_stencil, stencilfunction
do
	local stack = {}
	local sf, q, w, e, r, t, y, u, i
	function reset_stencil()
		stack = {}
		sf, q, w, e, r, t, y, u, i = nil
	end
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

---@param sf function|string?
---@param ... any?
function just.clip(sf, ...)
	if sf == "reset" then
		return reset_stencil()
	end
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

---@param t table
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

	for _, device in ipairs(devices) do
		clear_table(keyinput[device].pressed)
		clear_table(keyinput[device].released)
	end
	clear_table(mouse.pressed)
	clear_table(mouse.released)
	clear_table(zindexes)

	local any_mouse_over = next_hover_ids.mouse or next_hover_ids.wheel

	just.entered_id, just.exited_id = nil, nil
	catched_id, just.catched_id = nil, nil
	just.height = 0
	last_zindex = 0
	line_c = 0
	mouse.scroll_delta = 0
	mouse.captured = any_mouse_over or just.active_id

	textinput = ""

	clear_table(hover_ids)
	hover_ids, next_hover_ids = next_hover_ids, hover_ids

	clear_table(key_stack)
	key_stack, next_key_stack = next_key_stack, key_stack

	local new_over_id = hover_ids.mouse
	if over_id ~= new_over_id then
		just.exited_id = over_id
		over_id = new_over_id
		just.entered_id = new_over_id
	end
end

---@nocheck
function just.callbacks.mousepressed(_, _, button)
	mouse.down[button] = true
	mouse.pressed[button] = true
	return mouse.captured
end

---@nocheck
function just.callbacks.mousereleased(_, _, button)
	mouse.down[button] = nil
	mouse.released[button] = true
	return mouse.captured
end

---@nocheck
function just.callbacks.mousemoved()
	return mouse.captured
end

---@nocheck
function just.callbacks.wheelmoved(_, y)
	mouse.scroll_delta = y
	return mouse.captured
end

for i, device in ipairs(devices) do
	just.callbacks[device .. "pressed"] = function(...)
		local input = keyinput[device]
		local key = select(device_arg_index[i], ...)
		input.down[key] = true
		input.pressed[key] = true
	end
	just.callbacks[device .. "released"] = function(...)
		local input = keyinput[device]
		local key = select(device_arg_index[i], ...)
		input.down[key] = nil
		input.released[key] = true
	end
end

---@nocheck
function just.callbacks.textinput(text)
	textinput = textinput .. text
end

---@param depth number?
---@return boolean
function just.is_container_over(depth)
	local index = #container_overs - (depth or 1) + 1
	return #container_overs == 0 or container_overs[index]
end

---@return any?
function just.container_id()
	return containers[#containers]
end

---@param id any?
---@param over boolean?
---@param group string?
---@param new_zindex boolean?
---@return boolean?
function just.mouse_over(id, over, group, new_zindex)
	if not id then return end
	assert(group, "missing group")
	if not zindexes[id] or new_zindex then
		last_zindex = last_zindex + 1
		zindexes[id] = last_zindex
	end

	if rawequal(catched_id, id) then
		just.catched_id = id
	end

	local container_over = just.is_container_over()

	local next_hover_id = next_hover_ids[group]
	if over and container_over and (not next_hover_id or zindexes[id] > zindexes[next_hover_id]) then
		next_hover_ids[group] = id
	end

	return container_over and rawequal(id, hover_ids[group])
end

---@param id any?
---@param over boolean?
---@return number|boolean?
function just.wheel_over(id, over)
	local d = mouse.scroll_delta
	return just.mouse_over(id, over, "wheel") and d ~= 0 and d
end

local max_layer = 0

---@return boolean
function just.key_over()
	local layer = #containers
	if layer == 0 then
		return true
	end

	max_layer = math.max(max_layer, layer)

	local id = containers[layer]
	if next_key_stack[layer] ~= id then
		next_key_stack[layer] = id
		for i = layer + 1, max_layer do
			next_key_stack[i] = nil
		end
		max_layer = layer
	end

	return rawequal(key_stack[layer], id)
end

---@param id any?
---@param over boolean?
---@param button number?
---@return number?
---@return boolean?
---@return boolean?
function just.button(id, over, button)
	if not id then return end
	over = just.mouse_over(id, over, "mouse")
	button = button or next(mouse.pressed) or next(mouse.released) or next(mouse.down)
	if mouse.pressed[button] and over then
		just.active_id = id
	end

	local same_id = rawequal(just.active_id, id)

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

---@param id any?
---@param over boolean?
---@param pos number
---@param value number
---@return number|boolean?
---@return boolean?
---@return boolean?
function just.slider(id, over, pos, value)
	if not id then return end
	local _, active, hovered = just.button(id, over)

	local new_value = value
	if rawequal(just.active_id, id) then
		new_value = pos
	end

	return math.abs(new_value - value) > 1e-6 and new_value, active, hovered
end

---@param id any?
---@param over boolean?
---@return any?
function just.container(id, over)
	if not id then
		table.remove(container_overs)
		return table.remove(containers)
	end

	table.insert(containers, id)
	table.insert(container_overs, over)
end

---@param device string
---@param state string
function just.next_input(device, state)
	for i, _device in ipairs(devices) do
		if _device == device then
			return next(keyinput[device][state])
		end
	end
end

for i, device in ipairs(devices) do
	just[device .. "pressed"] = function(key, unset)
		local input = keyinput[device]
		local res = just.key_over() and input.pressed[key]
		if res and unset then
			input.pressed[key] = nil
		end
		return res
	end
	just[device .. "released"] = function(key, unset)
		local input = keyinput[device]
		local res = just.key_over() and input.released[key]
		if res and unset then
			input.released[key] = nil
		end
		return res
	end
end

---@param key number
---@return boolean?
function just.mousepressed(key)
	return mouse.pressed[key]
end

---@param key number
---@return boolean?
function just.mousereleased(key)
	return mouse.released[key]
end

---@param text string
---@param index number
---@return string
---@return string
local function text_split(text, index)
	local _index = utf8.offset(text, index) or 1
	return text:sub(1, _index - 1), text:sub(_index)
end

---@param text string
---@param index number
---@param forward boolean?
---@return string
---@return number
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

---@param text string
---@param index number?
---@return string|boolean
---@return string
---@return number
---@return string
---@return string
function just.textinput(text, index)
	text = tostring(text)
	index = index or utf8.len(text) + 1

	local left, right = text_split(text, index)
	if not just.key_over() then
		return false, text, index, left, right
	end

	local bt, bi = text, index

	local _text = textinput
	if _text ~= "" then
		local _left, _right = text_split(text, index)
		text = _left .. _text .. _right
		index = index + utf8.len(_text)
	end

	local pressed = keyinput.key.pressed
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

	return changed, text, index, left, right
end

just.reset()

return just
