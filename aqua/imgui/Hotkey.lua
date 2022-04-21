local imgui = require("cimgui")
local keymap = imgui.love.keymap

local activeId = nil
return function(label, k)
	local valueChanged = false
	local id = imgui.GetID_Str(label)

	local isActive = id == activeId
	if isActive then
		local key = k[0]

		for i = imgui.C.ImGuiKey_NamedKey_BEGIN, imgui.C.ImGuiKey_NamedKey_END - 1 do
			if imgui.IsKeyPressed(i) and keymap[i] then
				key = i
				valueChanged = true
				activeId = nil
			end
		end

		k[0] = key
		if keymap[key] == "escape" then
			k[0] = 0
		end
	end

	if imgui.BeginListBox(label, {0, imgui.GetFrameHeight()}) then
		if imgui.Selectable_Bool(keymap[k[0]] or "unknown", isActive) then
			activeId = id
		end
		imgui.EndListBox()
	end

	return valueChanged
end
