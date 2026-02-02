require("table.clear")

---@class core.LuvX
---@overload fun(metatable: view.Node, params: {[string]: any}, childen: view.Node[]?): nya.Node
local LuvX = {}

-- Temporary tables
local params = {}   -- Mixed styles and props
local children = {} -- Mixed children

---@param element view.Node | function
---@param ... ...
---@return view.Node
function LuvX.createElement(element, ...)
	local instance

	if type(element) == "function" then
		instance = element()
	elseif type(element) == "table" and not element.state then
		instance = element()
	else
		instance = element
	end

	table.clear(params)
	table.clear(children)

	for i = 1, select("#", ...) do
		local t = select(i, ...)

		if t then
			if t.updateTreeLayout then -- is a node
				table.insert(children, t)
			else
				for k, v in pairs(t) do
					params[k] = v
				end
			end
		end
	end

	if not next(params) then
		instance:init(params)
		for _, v in ipairs(children) do
			instance:add(v)
		end
		return instance
	end

	--[[
	for k, v in pairs(params) do
		if LuvX.props[k] then
			LuvX.props[k](instance, v)
		else
			leftovers[k] = v
		end
	end
	]]

	instance:init(params)

	for _, child in ipairs(children) do
		instance:add(child)
	end

	return instance
end

local mt = {
	__call = function(t, ...)
		return t.createElement(...)
	end
}

setmetatable(LuvX, mt) ---@diagnostic disable-line

return LuvX
