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

	---@diagnostic disable-next-line: no-unknown
	for param, value in parameters_values:gmatch(";%s*([^;]-)%s*=%s*([^;]+)%s*") do
		params[param] = value
	end
end

function MimeType:get_type_subtype()
	return ("%s/%s"):format(self.type, self.subtype)
end

---@param str string
---@param exact boolean?
---@return boolean
function MimeType:match(str, exact)
	local mime_type = MimeType(str)
	if not mime_type then
		return false
	end

	if self.type ~= mime_type.type or self.subtype ~= mime_type.subtype then
		return false
	end

	local params = self.params
	for k, v in pairs(mime_type.params) do
		if params[k] ~= v then
			return false
		end
	end

	if not exact then
		return true
	end

	params = mime_type.params
	for k, v in pairs(self.params) do
		if params[k] ~= v then
			return false
		end
	end

	return true
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
