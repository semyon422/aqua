local class = require("class")
local CookieDate = require("web.http.CookieDate")
local CookieSyntax = require("web.http.CookieSyntax")

---@class web.SetCookieString
---@operator call: web.SetCookieString
---@field attribute_list {[1]: string, [2]: string}[]
---@field name string
---@field value string
---@field ignore boolean
local SetCookieString = class()

---@param s string?
function SetCookieString:new(s)
	self.attribute_list = {}
	self.ignore = false
	if not s then return end
	local pair, attributes = s:match("^([^;]*)(.*)$")
	local name, value = pair:match("^(.-)=(.*)$")
	if not name then self.ignore = true return end
	name, value = CookieSyntax.trim(name), CookieSyntax.trim(value)
	if name == "" then self.ignore = true return end
	self.name, self.value = name, value
	for attribute in attributes:gmatch(";([^;]*)") do
		local attr_name, attr_value = attribute:match("^(.-)=(.*)$")
		if not attr_name then attr_name, attr_value = attribute, "" end
		self:add(CookieSyntax.trim(attr_name), CookieSyntax.trim(attr_value))
	end
end

---@param name string
---@param value string|number?
function SetCookieString:add(name, value)
	value = value == nil and "" or tostring(value)
	local lower = name:lower()
	if lower == "expires" then
		local date = CookieDate(value)
		if date.failed then return end
		name, value = "Expires", tostring(date)
	elseif lower == "max-age" then
		if not value:match("^%-?[0-9]+$") then return end
		if value:sub(1, 1) == "-" then value = "0"
		else value = value:gsub("^0+", "") end
		if value == "" then value = "0" end
		name = "Max-Age"
	elseif lower == "domain" then
		if value == "" then return end
		name, value = "Domain", value:gsub("^%.", ""):lower()
	elseif lower == "path" then
		-- Without a request URI, omitting an invalid Path delegates default-path to the browser.
		if value:sub(1, 1) ~= "/" then return end
		name = "Path"
	elseif lower == "secure" then
		name, value = "Secure", ""
	elseif lower == "httponly" then
		name, value = "HttpOnly", ""
	elseif lower == "samesite" then
		local same_site = {strict = "Strict", lax = "Lax", none = "None"}
		value = same_site[value:lower()]
		if not value then return end
		name = "SameSite"
	elseif name == "" then
		return
	end
	-- Last attribute wins when parsing; generated headers contain no duplicate attributes.
	for _, attribute in ipairs(self.attribute_list) do
		if attribute[1]:lower() == lower then
			attribute[1], attribute[2] = name, value
			return
		end
	end
	table.insert(self.attribute_list, {name, value})
end

---@param name string
---@return string?
function SetCookieString:get(name)
	for _, attribute in ipairs(self.attribute_list) do
		if attribute[1]:lower() == name:lower() then return attribute[2] end
	end
end

---@return string
function SetCookieString:__tostring()
	assert(not self.ignore, "cannot serialize an ignored cookie")
	assert(type(self.name) == "string" and CookieSyntax.validName(self.name), "invalid cookie name")
	assert(type(self.value) == "string" and CookieSyntax.validValue(self.value), "invalid cookie value")
	local out = {self.name .. "=" .. self.value}
	---@type {[string]: boolean}
	local seen = {}
	for _, attribute in ipairs(self.attribute_list) do
		local name, value = attribute[1], attribute[2]
		assert(CookieSyntax.validName(name), "invalid cookie attribute name")
		assert(CookieSyntax.validAttributeValue(value), "invalid cookie attribute value")
		local lower = name:lower()
		assert(not seen[lower], "duplicate cookie attribute")
		seen[lower] = true
		if lower == "domain" then
			assert(CookieSyntax.validDomain(value), "invalid cookie domain")
		elseif lower == "path" then
			assert(value:sub(1, 1) == "/", "invalid cookie path")
		elseif lower == "max-age" then
			assert(value == "0" or value:match("^[1-9][0-9]*$"), "invalid cookie max-age")
		elseif lower == "expires" then
			local date = CookieDate(value)
			assert(not date.failed and tostring(date) == value, "invalid cookie expires date")
		elseif lower == "secure" or lower == "httponly" then
			assert(value == "", "cookie flag must not have a value")
		elseif lower == "samesite" then
			assert(value == "Strict" or value == "Lax" or value == "None", "invalid cookie samesite")
		end
		table.insert(out, name .. (value ~= "" and "=" .. value or ""))
	end
	return table.concat(out, "; ")
end

return SetCookieString
