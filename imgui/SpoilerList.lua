local just = require("just")
local theme = require("imgui.theme")
local Spoiler = require("imgui.Spoiler")
local TextOnlyButton = require("imgui.TextOnlyButton")

---@generic T
---@param id any
---@param w number
---@param h number
---@param list T[]
---@param preview any
---@param to_string (fun(value: T): string)?
---@return integer?
---@return string?
return function(id, w, h, list, preview, to_string)
	---@type integer?, string?
	local _i, _name
	if Spoiler(id, w, h, preview) then
		love.graphics.setColor(0, 0, 0, 1)
		love.graphics.rectangle("fill", 0, 0, w, h * theme.size * #list)
		love.graphics.setColor(1, 1, 1, 1)
		-- LuaLS 3.19 loses the generic array value type through ipairs().
		---@diagnostic disable-next-line: no-unknown
		for i, value in ipairs(list) do
			local name = to_string and to_string(value) or tostring(value)
			if TextOnlyButton("spoiler" .. i, name, w - h * (1 - theme.size), h * theme.size, "center") then
				_i, _name = i, name
				just.focus()
			end
		end
		Spoiler()
	end
	return _i, _name
end
