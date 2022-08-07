local imgui = require("cimgui")
local just = require("just")
local config = require("aqua.imgui.config")
local transform = require("aqua.graphics.transform")

local function getPos(x, y)
	local tf = transform(config.transform)
	return tf:inverseTransformPoint(x, y)
end

local imguicb = {}

imguicb.mousemoved = function(x, y)
	x, y = getPos(x, y)
	imgui.love.MouseMoved(x, y)
	return imgui.love.GetWantCaptureMouse() or just.callbacks.mousemoved(x, y)
end

imguicb.mousepressed = function(x, y, button)
	x, y = getPos(x, y)
	imgui.love.MousePressed(button)
	return imgui.love.GetWantCaptureMouse() or just.callbacks.mousepressed(x, y, button)
end

imguicb.mousereleased = function(x, y, button)
	x, y = getPos(x, y)
	imgui.love.MouseReleased(button)
	return imgui.love.GetWantCaptureMouse() or just.callbacks.mousereleased(x, y, button)
end

imguicb.wheelmoved = function(x, y)
	imgui.love.WheelMoved(x, y)
	return imgui.love.GetWantCaptureMouse() or just.callbacks.wheelmoved(x, y)
end

imguicb.keypressed = function(key, scancode, isrepeat)
	imgui.love.KeyPressed(scancode)
	return imgui.love.GetWantCaptureKeyboard() or just.callbacks.keypressed(key, scancode, isrepeat)
end

imguicb.keyreleased = function(key, scancode, isrepeat)
	imgui.love.KeyReleased(scancode)
	return imgui.love.GetWantCaptureKeyboard() or just.callbacks.keyreleased(key, scancode, isrepeat)
end

imguicb.textinput = function(text)
	imgui.love.TextInput(text)
	return imgui.love.GetWantCaptureKeyboard() or just.callbacks.textinput(text)
end

imguicb.quit = function()
	imgui.love.Shutdown()
end

imguicb.joystickadded = function(joystick)
	imgui.love.JoystickAdded(joystick)
end

imguicb.joystickremoved = function()
	imgui.love.JoystickRemoved()
end

imguicb.gamepadpressed = function(_, button)
	imgui.love.GamepadPressed(button)
end

imguicb.gamepadreleased = function(_, button)
	imgui.love.GamepadReleased(button)
end

imguicb.gamepadaxis = function(_, axis, value)
	imgui.love.GamepadAxis(axis, value, 0.1)
end

return imguicb
