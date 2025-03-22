local class = require("class")
local socket_url = require("socket.url")
local CookieDate = require("web.http.CookieDate")

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

---@param a string
---@param b string
---@return boolean
local function eq_lower(a, b)
	return a:lower() == b:lower()
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

		self:add(trim_name_value(_name, _value))
	end
end

---@param name string
---@param value any?
function SetCookieString:add(name, value)
	value = tostring(value or "")

	if eq_lower(name, "Expires") then
		local expiry_time = CookieDate(value)
		if expiry_time.failed then
			return
		end
		table.insert(self.attribute_list, {"Expires", expiry_time:get_unix_time()})
	elseif eq_lower(name, "Max-Age") then
		local first_char = value:sub(1, 1)
		if not first_char:match("%d") and first_char ~= "-" then
			return
		end
		if value:match("[^%d]", 2) then
			return
		end
		local delta_seconds = tonumber(value)
		---@type integer
		local expiry_time
		if delta_seconds <= 0 then
			expiry_time = 0
		else
			expiry_time = os.time() + delta_seconds
		end
		table.insert(self.attribute_list, {"Max-Age", expiry_time})
	elseif eq_lower(name, "Domain") then
		if value == "" then
			return
		end
		local cookie_domain = value
		if value:sub(1, 1) == "." then
			cookie_domain = value:sub(2)
		end
		cookie_domain = cookie_domain:lower()
		table.insert(self.attribute_list, {"Domain", cookie_domain})
	elseif eq_lower(name, "Path") then
		local cookie_path = value
		if value == "" or value:sub(1, 1) ~= "/" then
			cookie_path = ""  -- TODO: default-path
		end
		table.insert(self.attribute_list, {"Path", cookie_path})
	elseif eq_lower(name, "Secure") then
		table.insert(self.attribute_list, {"Secure", ""})
	elseif eq_lower(name, "HttpOnly") then
		table.insert(self.attribute_list, {"HttpOnly", ""})
	elseif eq_lower(name, "SameSite") then
		if eq_lower(value, "Strict") then
			table.insert(self.attribute_list, {"SameSite", "Strict"})
		elseif eq_lower(value, "Lax") then
			table.insert(self.attribute_list, {"SameSite", "Lax"})
		elseif eq_lower(value, "None") then
			table.insert(self.attribute_list, {"SameSite", "None"})
		end
	end
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
