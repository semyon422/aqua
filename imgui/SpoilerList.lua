local just = require("just")
local theme = require("imgui.theme")
local Spoiler = require("imgui.Spoiler")
local TextOnlyButton = require("imgui.TextOnlyButton")

return function(id, w, h, list, preview, to_string)
	local _i, _name
	if Spoiler(id, w, h, preview) then
		love.graphics.setColor(0, 0, 0, 1)
		love.graphics.rectangle("fill", 0, 0, w, h * theme.size * #list)
		love.graphics.setColor(1, 1, 1, 1)
		for i, name in ipairs(list) do
			name = to_string and to_string(name) or name
			if TextOnlyButton("spoiler" .. i, name, w - h * (1 - theme.size), h * theme.size, "center") then
				_i, _name = i, name
				just.focus()
			end
		end
		Spoiler()
	end
	return _i, _name
end
