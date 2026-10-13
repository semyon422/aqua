---@class web.CookieSyntax
local CookieSyntax = {}

local separators = '()<>@,;:\\"/[]?={} '

---@param value string
---@return boolean
function CookieSyntax.validName(value)
	if value == "" then return false end
	for i = 1, #value do
		local byte = value:byte(i)
		if byte < 33 or byte > 126 or separators:find(value:sub(i, i), 1, true) then
			return false
		end
	end
	return true
end

---@param value string
---@return boolean
function CookieSyntax.validValue(value)
	if value:sub(1, 1) == '"' and value:sub(-1) == '"' and #value >= 2 then
		value = value:sub(2, -2)
	end
	for i = 1, #value do
		local byte = value:byte(i)
		if byte < 33 or byte > 126 or byte == 34 or byte == 44 or byte == 59 or byte == 92 then
			return false
		end
	end
	return true
end

---@param value string
---@return boolean
function CookieSyntax.validAttributeValue(value)
	for i = 1, #value do
		local byte = value:byte(i)
		if byte < 32 or byte > 126 or byte == 59 then return false end
	end
	return true
end

---@param value string
---@return boolean
function CookieSyntax.validDomain(value)
	if value == "" or #value > 253 or value:find("[^a-zA-Z0-9.%-]")
		or value:sub(1, 1) == "." or value:sub(-1) == "." or value:find("..", 1, true)
	then
		return false
	end
	for label in value:gmatch("[^.]+") do
		if #label > 63 or label:sub(1, 1) == "-" or label:sub(-1) == "-" then return false end
	end
	return true
end

---@param value string
---@return string
function CookieSyntax.trim(value)
	return (value:gsub("^[ \t]+", ""):gsub("[ \t]+$", ""))
end

return CookieSyntax
