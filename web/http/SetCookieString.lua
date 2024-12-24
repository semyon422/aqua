local class = require("class")
local socket_url = require("socket.url")

---@class web.SetCookieString
---@operator call: web.SetCookieString
---@field attribute_list {[1]: string, [2]: string}[]
---@field name string
---@field value string
---@field ignore boolean
local SetCookieString = class()

---@param name string
---@param value string
---@return string
---@return string
local function trim_name_value(name, value)
	return name:match("^%s*(.-)%s*$"), value:match("^%s*(.-)%s*$")
end

---@param s string?
function SetCookieString:new(s)
	self.attribute_list = {}

	if not s then
		return
	end

	-- https://www.rfc-editor.org/rfc/rfc6265#section-5.2

	-- algorithm to parse a "set-cookie-string"

	local name_value_pair, unparsed_attributes = s, ""

	if s:find(";") then
		---@type string, string
		name_value_pair, unparsed_attributes = s:match("^(.-)(;.+)$")
	end

	if not name_value_pair:find("=") then
		self.ignore = true
		return
	end

	local name, value = trim_name_value(name_value_pair:match("^(.-)=(.*)$"))

	if name == "" then
		self.ignore = true
		return
	end

	self.name = name
	self.value = value

	-- algorithm to parse the unparsed-attributes

	if unparsed_attributes == "" then
		return
	end

	for cookie_av in unparsed_attributes:gmatch(";([^;]*)") do
		local _name, _value = cookie_av, ""

		if cookie_av:find("=") then
			---@type string, string
			_name, _value = cookie_av:match("^(.-)=(.*)$")
		end

		_name, _value = trim_name_value(_name, _value)

		table.insert(self.attribute_list, {_name, _value})
	end
end

---@param name string
---@param value any?
function SetCookieString:add(name, value)
	value = value or ""
	table.insert(self.attribute_list, {name, tostring(value)})
end

---@param name string
---@return string?
function SetCookieString:get(name)
	for _, av in ipairs(self.attribute_list) do
		if av[1] == name then
			return av[2]
		end
	end
end

---@return string
function SetCookieString:__tostring()
	local out = {("%s=%s"):format(self.name, self.value)}
	for _, av in ipairs(self.attribute_list) do
		---@type string, string
		local name, value = socket_url.escape(av[1]), av[2]
		if value ~= "" then
			table.insert(out, ("%s=%s"):format(name, socket_url.escape(value)))
		else
			table.insert(out, ("%s"):format(name))
		end
	end
	return table.concat(out, "; ")
end

return SetCookieString
