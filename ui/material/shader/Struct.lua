local class = require("class")

---@class ui.Shader.Struct
---@operator call: ui.Shader.Struct
---@field name string
---@field fields string[]
local Struct = class()

---@param name string
function Struct:new(name)
	self.name = assert(name)
	self.fields = {}
end

---@param type string
---@param name string
---@param index integer?
---@return string name
function Struct:addField(type, name, index)
	assert(type and name)
	if index then
		name = name .. index
	end
	table.insert(self.fields, ("%s %s"):format(type, name))
	return name
end

function Struct:__tostring()
	return ("struct %s {\n\t%s;\n};\n"):format(self.name, table.concat(self.fields, ";\n\t"))
end

return Struct
