local class = require("class")

---@class ui.Shader.Function
---@operator call: ui.Shader.Function
local Function = class()

---@param return_type string
---@param name string
function Function:new(return_type, name)
	self.return_type = return_type
	self.name = name
	self.arguments = {}
	self.code = {}
end

---@param type string
---@param name string
function Function:addArgument(type, name)
	table.insert(self.arguments, ("%s %s"):format(type, name))
end

---@param line string
function Function:addLine(line)
	table.insert(self.code, line)
end

function Function:__tostring()
	return ("%s %s(%s) {\n\t%s\n}\n"):format(
		self.return_type,
		self.name,
		table.concat(self.arguments, ", "),
		table.concat(self.code, "\n\t")
	)
end

return Function
