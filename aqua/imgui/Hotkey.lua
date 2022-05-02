local ffi = require("ffi")
local imgui = require("cimgui")
local aquaevent = require("aqua.event")

local midistate = aquaevent.midistate
local keystate = aquaevent.keystate
local gamepadstate = aquaevent.gamepadstate

local allstates = {
	midi = midistate,
	keyboard = keystate,
	gamepad = gamepadstate
}

local activeId = nil
return function(label, keyPtr, devicePtr)
	local valueChanged = false
	local id = imgui.GetID_Str(label)

	local isActive = id == activeId
	if isActive then
		local key
		local device

		for d, states in pairs(allstates) do
			for k, v in pairs(states) do
				if v then
					key = k
					device = d
					valueChanged = true
					activeId = nil
					break
				end
			end
			if valueChanged then
				break
			end
		end

		if not key or key == "escape" then
			valueChanged = false
		else
			keyPtr[0] = tostring(key)
			devicePtr[0] = device
		end
	end

	local device = ffi.string(devicePtr[0])
	local keyName = ffi.string(keyPtr[0])
	if imgui.BeginListBox(label, {0, imgui.GetFrameHeight()}) then
		if imgui.Selectable_Bool(("%s (%s)"):format(keyName, device), isActive) then
			activeId = id
		end
		imgui.EndListBox()
	end

	return valueChanged
end
