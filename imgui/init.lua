local just = require("just")
local theme = require("imgui.theme")
local autoload = require("autoload")
local math_util = require("math_util")

local imgui = autoload("imgui")

local w, h, _w, _h
function imgui.setSize(...)
	w, h, _w, _h = ...
end

function imgui.separator()
	just.emptyline(8)
	love.graphics.line(0, 0, w, 0)
	just.emptyline(8)
end

function imgui.indent(size)
	just.indent(size or 8)
end

function imgui.unindent(size)
	just.indent(-(size or 8))
end

function imgui.label(id, label)
	if not label then
		just.next()
		return
	end
	imgui.indent()
	imgui.Label(id, label, _h)
end

function imgui.text(text)
	imgui.indent()
	just.text(text)
end

function imgui.button(id, text)
	local width = love.graphics.getFont():getWidth(text)
	return imgui.TextButton(id, text, width + _h * 2 * theme.padding, _h)
end

function imgui.slider(id, v, a, b, displayValue, label)
	local _v = math_util.map(v, a, b, 0, 1)
	_v = imgui.Slider(id, _v, _w, _h, displayValue) or _v
	just.sameline()
	imgui.label(id .. "label", label)
	return math_util.map(_v, 0, 1, a, b)
end

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

function imgui.combo(id, v, values, to_string, label)
	local fv = to_string and to_string(v) or v
	local i = imgui.SpoilerList(id, _w, _h, values, fv, to_string)
	just.sameline()
	imgui.label(id .. "label", label)
	return i and values[i] or v
end

local scrolls = {}
function imgui.list(id, v, values, height, format, label)
	scrolls[id] = scrolls[id] or 0
	imgui.List(id, _w, height, _h, scrolls[id])
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

function imgui.intButtons(id, v, s, label)
	just.row(true)
	local bw = _w / (s + 2)
	local button = imgui.TextButton(nil, v, bw, _h)
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

function imgui.hotkey(id, key, label)
	local _
	_, key = imgui.Hotkey(id, "keyboard", key, _w, _h)
	just.sameline()
	imgui.label(id .. "label", label)
	return key
end

function imgui.input(id, text, label)
	local _
	_, text = imgui.TextInput(id, text, nil, _w, _h)
	just.sameline()
	imgui.label(id .. "label", label)
	return text
end

return imgui
