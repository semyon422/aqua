local just = require("just")
local theme = require("imgui.theme")
local autoload = require("autoload")
local math_util = require("math_util")
local gfx_util = require("gfx_util")
local decibel = require("decibel")

local imgui = autoload("imgui")

local w, h, _w, _h

---@param ... number
function imgui.setSize(...)
	w, h, _w, _h = ...
end

function imgui.separator()
	just.emptyline(8)
	love.graphics.line(0, 0, w, 0)
	just.emptyline(8)
end

---@param size number?
function imgui.indent(size)
	just.indent(size or _h * theme.indent)
end

---@param size number?
function imgui.unindent(size)
	just.indent(-(size or _h * theme.indent))
end

---@param id any
---@param label string?
function imgui.label(id, label)
	if not label then
		just.next()
		return
	end
	imgui.indent()
	imgui.Label(id, label, _h)
end

---@param text string
---@param limit number?
---@param right boolean?
---@return number
---@return number
function imgui.text(text, limit, right)
	imgui.indent()
	return just.text(text, limit, right)
end

---@param id any
---@param text string
---@param url string
---@param isLabel boolean?
function imgui.url(id, text, url, isLabel)
	local font = love.graphics.getFont()
	local width = font:getWidth(text)
	local height = _h
	if not isLabel then
		height = font:getHeight() * font:getLineHeight()
	end

	local changed, active, hovered = just.button(id, just.is_over(width, height))
	just.push("all")
	love.graphics.setColor(0, 0.5, 1)
	if hovered then
		love.graphics.setColor(0, 0.7, 1)
	end
	if active then
		love.graphics.setColor(0, 0.8, 1)
	end
	gfx_util.printFrame(text, 0, 0, width, height, "left", "center")
	just.pop()

	if changed then
		love.system.openURL(url)
	end
	just.next(width, height)
end

---@param id any
---@param text string
---@return number?
function imgui.button(id, text, inactive)
	local width = love.graphics.getFont():getWidth(text)
	return imgui.TextButton(id, text, width + _h * 2 * theme.padding, _h, inactive)
end

---@param id any
---@param v number
---@param a number
---@param b number
---@param displayValue number|string
---@param label string?
---@return number
function imgui.slider(id, v, a, b, displayValue, label)
	local _v = math_util.map(v, a, b, 0, 1)
	_v = imgui.Slider(id, _v, _w, _h, displayValue) or _v
	just.sameline()
	imgui.label(id .. "label", label)
	return math_util.map(_v, 0, 1, a, b)
end

---@param id any
---@param v number
---@param format string
---@param a number
---@param b number
---@param c number
---@param label string?
---@return number
function imgui.slider1(id, v, format, a, b, c, label)
	local delta = just.wheel_over(id, just.is_over(_w, _h))
	if delta then
		v = math.min(math.max(v + c * delta, a), b)
	end

	local _v = math_util.map(v, a, b, 0, 1)
	_v = imgui.Slider(id, _v, _w, _h, format:format(v)) or _v
	just.sameline()
	imgui.label(id .. "label", label)

	v = math_util.map(_v, 0, 1, a, b)
	v = math_util.round(v, c)

	return v
end

---@param id any
---@param v number
---@param format string
---@param a number
---@param b number
---@param c number
---@param k number
---@param label string?
---@return number
function imgui.logslider(id, v, format, a, b, c, k, label)
	local lv = math_util.round(math.log(v) * k, c)
	lv = imgui.slider1(id, lv, format, a, b, c, label)
	return math.exp(lv / k)
end

---@param id any
---@param v number
---@param format string
---@param a number
---@param b number
---@param c number
---@param label string?
---@return number
function imgui.lfslider(id, v, format, a, b, c, label)
	local lv = math_util.round(decibel.f_to_lf(v), c)
	lv = imgui.slider1(id, lv, format, a, b, c, label)
	return decibel.lf_to_f(lv)
end

---@param id any
---@param v boolean|number
---@param label string?
---@return boolean|number
function imgui.checkbox(id, v, label)
	local isNumber = type(v) == "number"
	if isNumber then
		v = v == 1
	end
	if imgui.Checkbox(id, v, _h) then
		v = not v
	end
	just.sameline()
	imgui.label(id, label)
	if isNumber then
		v = v and 1 or 0
	end
	return v
end

---@param id any
---@param v boolean|number
---@param text string
---@return boolean|number
function imgui.textcheckbox(id, v, text)
	local isNumber = type(v) == "number"
	if isNumber then
		v = v == 1
	end
	local width = love.graphics.getFont():getWidth(text)
	if imgui.TextCheckbox(id, v, text, width + _h, _h) then
		v = not v
	end
	if isNumber then
		v = v and 1 or 0
	end
	return v
end

---@param id any
---@param v any
---@param values table
---@param to_string function?
---@param label string?
---@return any
function imgui.combo(id, v, values, to_string, label)
	local fv = to_string and to_string(v) or v
	local i = imgui.SpoilerList(id, _w, _h, values, fv, to_string)
	just.sameline()
	imgui.label(id .. "label", label)
	return i and values[i] or v
end

local scrolls = {}

---@param id any
---@param v number|string
---@param values table
---@param height number
---@param format function?
---@param label string?
---@return number|string
function imgui.list(id, v, values, height, format, label)
	scrolls[id] = scrolls[id] or 0
	imgui.List(id, _w, height, _h / 3, _h, scrolls[id])
	for i, _v in ipairs(values) do
		local dv = format and format(_v) or _v
		if imgui.TextOnlyButton(id .. i, dv, _w - _h * (1 - theme.size), _h * theme.size) then
			v = _v
		end
	end
	scrolls[id] = imgui.List()
	just.sameline()
	imgui.label(id .. "label", label)
	return v
end

---@param id any
---@param v number
---@param s number
---@param label string?
---@return number
function imgui.intButtons(id, v, s, label)
	just.row(true)
	local bw = _w / (s + 2)
	local button = v and imgui.TextButton(nil, v, bw, _h)
	v = v or 0
	for i = 0, s do
		local d = 10 ^ i
		button = imgui.TextButton(id .. d, "±" .. d, bw, _h)
		if button then
			v = v + (button == 1 and 1 or -1) * d
		end
	end
	imgui.label(id .. "label", label)
	just.row()
	return math.floor(v)
end

---@param id any
---@param key string
---@param label string?
---@return string
function imgui.hotkey(id, key, label)
	local _, _key = imgui.Hotkey(id, key, _w, _h)
	just.sameline()
	imgui.label(id .. "label", label)
	return _key or key
end

---@param id any
---@param text any?
---@param label string?
---@return string
function imgui.input(id, text, label)
	local _
	_, text = imgui.TextInput(id, text, nil, _w, _h)
	just.sameline()
	imgui.label(id .. "label", label)
	return text
end

---@param id any
---@param item string
---@param items table
---@return string
function imgui.tabs(id, item, items)
	return imgui.TabBar(id, item, items, w, _h)
end

---@param id any
---@param item string
---@param items table
---@return string
---@return number
function imgui.vtabs(id, item, items)
	return imgui.TabColumn(id, item, items, h, _h)
end

---@param id any
---@param v number
---@param a number
---@param b number
---@param c number
---@param drag_w number
---@param label string?
---@return number
function imgui.knob(id, v, a, b, c, drag_w, label)
	local delta = just.wheel_over(id, just.is_over(_w, _h))
	if delta then
		v = math.min(math.max(v + c * delta, a), b)
	end

	local _v = math_util.map(v, a, b, 0, 1)
	_v = imgui.Knob(id, _v, _h, drag_w) or _v
	just.sameline()
	imgui.label(id .. "label", label)

	v = math_util.map(_v, 0, 1, a, b)
	v = math_util.round(v, c)

	return v
end

return imgui
