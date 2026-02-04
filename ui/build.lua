require("table.clear")

-- Temporary tables
local params = {}   -- Mixed styles and props

---@param n table?
---@return boolean
local function isNode(n)
	if n == nil then
		return false
	end
	if type(n) == "table" and n.updateTreeTransform then
		return true
	end
	return false
end

---@alias LuvX.Node {[1]: view.Node, [string]: any, [integer]: LuvX.Node | {[string]: any} }

---@param t LuvX.Node
---@return view.Node
local function build(t)
	local instance = t[1]()

	table.clear(params)

	for k, v in pairs(t) do
		if type(k) == "string" then
			params[k] = v
		elseif type(v) == "table" and not isNode(v[1]) then
			for k2, v2 in pairs(v) do
				params[k2] = v2
			end
		end
	end

	instance:setup(params)

	for _, v in ipairs(t) do
		if type(v) == "function" then
			instance:add(v())
		elseif type(v) == "table" and isNode(v[1]) then
			---@cast v LuvX.Node
			instance:add(build(v))
		end
	end

	return instance
end

return build
