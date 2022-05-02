local imgui = require("cimgui")
local Devices = require("aqua.imgui.Devices")

local keymap = imgui.love.keymap
local gamepad_map = imgui.love.gamepad_map

local Keymap = {}

function Keymap:get(keyPtr, devicePtr)
	local device = Devices[devicePtr[0]] or "unknown"
	local key = "unknown"
	if device == "keyboard" then
		key = keymap[keyPtr[0]]
	elseif device == "gamepad" then
		key = gamepad_map[keyPtr[0]]
	elseif device == "midi" then
		key = keyPtr[0]
	end
	return key, device
end

function Keymap:set(keyPtr, devicePtr, key, device)
	if device == "keyboard" then
		local k = keymap[key]
		if type(k) == "table" then
			k = k[1]
		end
		keyPtr[0] = k or 0
		devicePtr[0] = Devices.keyboard
	elseif device == "gamepad" then
		local k = gamepad_map[key]
		if type(k) == "table" then
			k = k[1]
		end
		keyPtr[0] = k or 0
		devicePtr[0] = Devices.gamepad
	elseif device == "midi" then
		keyPtr[0] = key or 0
		devicePtr[0] = Devices.midi
	else
		keyPtr[0] = 0
		devicePtr[0] = 0
	end
end

return Keymap
