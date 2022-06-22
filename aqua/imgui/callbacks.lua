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
	local captured = just.mousemoved(x, y)
	return imgui.love.GetWantCaptureMouse() or captured
end

imguicb.mousepressed = function(x, y, button)
	x, y = getPos(x, y)
	imgui.love.MousePressed(button)
	local captured = just.mousepressed(x, y, button)
	return imgui.love.GetWantCaptureMouse() or captured
end

imguicb.mousereleased = function(x, y, button)
	x, y = getPos(x, y)
	imgui.love.MouseReleased(button)
	local captured = just.mousereleased(x, y, button)
	return imgui.love.GetWantCaptureMouse() or captured
end

imguicb.wheelmoved = function(x, y)
	x, y = getPos(x, y)
	imgui.love.WheelMoved(x, y)
	local captured = just.wheelmoved(x, y)
	return imgui.love.GetWantCaptureMouse() or captured
end

imguicb.keypressed = function(_, key)
	imgui.love.KeyPressed(key)
	return imgui.love.GetWantCaptureKeyboard()
end

imguicb.keyreleased = function(_, key)
	imgui.love.KeyReleased(key)
	return imgui.love.GetWantCaptureKeyboard()
end

imguicb.textinput = function(t)
	imgui.love.TextInput(t)
	return imgui.love.GetWantCaptureKeyboard()
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
