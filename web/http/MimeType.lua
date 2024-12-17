local class = require("class")

---@class web.MimeType
---@operator call: web.MimeType
local MimeType = class()

---@param str string
function MimeType:new(str)
	---@type string, string, string
	local _type, subtype, parameters_values = str:match("^%s*([%w%-]+)/([%w%-]+)%s*([;]*.*)$")
	if not _type then
		return nil, "invalid MIME type"
	end

	self.type = _type
	self.subtype = subtype

	---@type {[string]: string}
	local params = {}
	self.params = params

	for param, value in parameters_values:gmatch(";%s*([^;]-)%s*=%s*([^;]+)%s*") do
		params[param] = value
	end
end

function MimeType:__tostring()
	local out = {}

	table.insert(out, self.type)
	table.insert(out, "/")
	table.insert(out, self.subtype)

	for param, value in pairs(self.params) do
		table.insert(out, "; ")
		table.insert(out, param)
		table.insert(out, "=")
		table.insert(out, value)
	end

	return table.concat(out)
end

return MimeType
