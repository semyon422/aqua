local imgui = require("cimgui")
local config = require("aqua.imgui.config")
local transform = require("aqua.graphics.transform")

local imguicb = {}

imguicb.mousemoved = function(x, y)
	local tf = transform(config.transform)
	x, y = tf:inverseTransformPoint(x, y)
	imgui.love.MouseMoved(x, y)
	return imgui.love.GetWantCaptureMouse()
end

imguicb.mousepressed = function(_, _, button)
    imgui.love.MousePressed(button)
    return imgui.love.GetWantCaptureMouse()
end

imguicb.mousereleased = function(_, _, button)
    imgui.love.MouseReleased(button)
    return imgui.love.GetWantCaptureMouse()
end

imguicb.wheelmoved = function(x, y)
	local tf = transform(config.transform)
	x, y = tf:inverseTransformPoint(x, y)
    imgui.love.WheelMoved(x, y)
    return imgui.love.GetWantCaptureMouse()
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
