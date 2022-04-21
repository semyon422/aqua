local imgui = require("cimgui")
local aquaevent = require("aqua.event")
local Devices = require("aqua.imgui.Devices")

local keymap = imgui.love.keymap
local gamepad_map = imgui.love.gamepad_map

local midikeys = aquaevent.midikeys

local activeId = nil
return function(label, keyPtr, devicePtr)
	local valueChanged = false
	local id = imgui.GetID_Str(label)

	local isActive = id == activeId
	if isActive then
		local key = keyPtr[0]

		for i = imgui.C.ImGuiKey_NamedKey_BEGIN, imgui.C.ImGuiKey_NamedKey_END - 1 do
			if imgui.IsKeyPressed(i) then
				key = i
				valueChanged = true
				activeId = nil
				if keymap[i] then
					devicePtr[0] = Devices.keyboard
				elseif gamepad_map[i] then
					devicePtr[0] = Devices.gamepad
				else
					devicePtr[0] = Devices.unknown
				end
			end
		end
		if not valueChanged then
			for i = 1, 88 do
				if midikeys[i] then
					key = i
					valueChanged = true
					activeId = nil
					devicePtr[0] = Devices.midi
				end
			end
		end

		keyPtr[0] = key
		if keymap[key] == "escape" then
			keyPtr[0] = 0
		end
	end

	local device = Devices[devicePtr[0]]
	local keyName = "unknown"
	if device == "keyboard" then
		keyName = keymap[keyPtr[0]]
	elseif device == "gamepad" then
		keyName = gamepad_map[keyPtr[0]]
	elseif device == "midi" then
		keyName = tostring(keyPtr[0])
	end
	if imgui.BeginListBox(label, {0, imgui.GetFrameHeight()}) then
		if imgui.Selectable_Bool(("%s (%s)"):format(keyName, device), isActive) then
			activeId = id
		end
		imgui.EndListBox()
	end

	return valueChanged
end
