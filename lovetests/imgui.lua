local just = require("just")
local imgui = require("imgui")

local event_message = "no event"

local callbacks = {
	"mousepressed",
	"mousereleased",
	"mousemoved",
	"wheelmoved",
	"keypressed",
	"keyreleased",
	"textinput",
}

local function transformInputEvent(name, ...)
	if name == "keypressed" then
		return "keyboard", 1, select(2, ...), true
	elseif name == "keyreleased" then
		return "keyboard", 1, select(2, ...), false
	elseif name == "gamepadpressed" then
		return "gamepad", select(1, ...):getID(), select(2, ...), true
	elseif name == "gamepadreleased" then
		return "gamepad", select(1, ...):getID(), select(2, ...), false
	elseif name == "joystickpressed" then
		return "joystick", select(1, ...):getID(), select(2, ...), true
	elseif name == "joystickreleased" then
		return "joystick", select(1, ...):getID(), select(2, ...), false
	elseif name == "midipressed" then
		return "midi", 1, select(1, ...), true
	elseif name == "midireleased" then
		return "midi", 1, select(1, ...), false
	end
end

local function resend_transformed(...)
	if not ... then return end
	local icb = just.callbacks.inputchanged(...)
end

for _, name in ipairs(callbacks) do
	love[name] = function(...)
		event_message = ("%s: " .. ("%s, "):rep(select("#", ...) - 1) .. "%s"):format(name, ...)
		resend_transformed(transformInputEvent(name, ...))
		local icb = just.callbacks[name]
		if icb and icb(...) then return end
	end
end

local mx, my = 0, 0

local windowOpened = true
local win_x = 100
local win_y = 100

local counter = 0
local sliderValue = 0
local cbValue = false
local cmbValue = "a"
local listValue = "a"
local hotkeyValue = "a"
local textValue = ""
local scrollY = 0
local scrollY2 = 0
function love.draw()
	local _mx, _my = love.mouse.getPosition()
	local dmx, dmy = _mx - mx, _my - my

	just.text(event_message)

	imgui.setSize(400, 400, 200, 32)

	if imgui.button("btn1", "add 1") then
		counter = counter + 1
	end
	just.sameline()
	imgui.label("lbl1", "Count: " .. counter)

	sliderValue = imgui.slider1("sld1", sliderValue, "%s", 0, 1000, 10, "slider")
	cbValue = imgui.checkbox("cb1", cbValue, "checkbox")
	cmbValue = imgui.combo("cmb1", cmbValue, {"a", "b", "c"}, nil, "combo")
	listValue = imgui.list("list1", listValue, {"a", "b", "c", "d", "e"}, 90, nil, "list - " .. listValue)
	hotkeyValue = imgui.hotkey("htk1", hotkeyValue, "hotkey")
	textValue = imgui.input("txt1", textValue, "text input")

	local scroll_w, scroll_step = 11, 32
	do
		just.text("Container")
		local cw, ch = 200, 200
		just.push()
		imgui.Container("cont1", cw, ch, scroll_w, scroll_step, scrollY)

		for i = 1, 20 do
			imgui.button("cont1-" .. i, "button " .. i)
		end

		scrollY = imgui.Container()
		just.pop()
		love.graphics.rectangle("line", 0, 0, cw, ch)
		just.next(cw, ch)
	end

	if imgui.button("openw", "open window") then
		windowOpened = not windowOpened
	end

	if windowOpened then
		love.graphics.origin()
		love.graphics.translate(win_x, win_y)

		just.text("Window")
		local cw, ch = 400, 400
		just.push()
		love.graphics.setColor(0, 0, 0, 0.8)
		love.graphics.rectangle("fill", 0, 0, cw, ch)
		love.graphics.setColor(1, 1, 1, 1)

		imgui.Container("cont2", cw, ch, scroll_w, scroll_step, scrollY2)

		just.text("drag to move")
		just.button("cont2", true)
		if just.active_id == "cont2" then
			win_x, win_y = win_x + dmx, win_y + dmy
		end

		hotkeyValue = imgui.hotkey("htk2", hotkeyValue, "hotkey")
		if just.keypressed("escape") then
			windowOpened = false
		end
		if imgui.button("cls2", "close") then
			windowOpened = false
		end
		just.sameline()
		imgui.label("lblcls", "or press escape")

		local kp_text = 'just.keypressed("q") == '
		local pressed = just.keypressed("q")
		imgui.checkbox("rcb1", pressed, kp_text .. tostring(pressed))

		imgui.List("c list1", 400, 40, scroll_w, scroll_step, 0)
		do
			pressed = just.keypressed("q")
			imgui.checkbox("rcb2", pressed, kp_text .. tostring(pressed))
		end
		imgui.List()

		imgui.List("c list2", 400, 180, scroll_w, scroll_step, 0)
		do
			pressed = just.keypressed("q")
			imgui.checkbox("rcb3", pressed, kp_text .. tostring(pressed))
			imgui.List("c list3", 300, 40, scroll_w, scroll_step, 0)
			do
				pressed = just.keypressed("q")
				imgui.checkbox("rcb33", pressed, kp_text .. tostring(pressed))
			end
			imgui.List()
			imgui.List("c list4", 300, 40, scroll_w, scroll_step, 0)
			do
				pressed = just.keypressed("q")
				imgui.checkbox("rcb4", pressed, kp_text .. tostring(pressed))
			end
			imgui.List()
		end
		imgui.List()

		scrollY2 = imgui.Container()
		just.pop()
		love.graphics.setColor(1, 1, 1, 1)
		love.graphics.rectangle("line", 0, 0, cw, ch)
		just.next(cw, ch)
	end

	mx, my = _mx, _my
	just._end()
end
