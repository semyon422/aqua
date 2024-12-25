local class = require("class")

-- https://www.rfc-editor.org/rfc/rfc6265#section-5.1.1

---@class web.CookieDate
---@operator call: web.CookieDate
---@field failed boolean
local CookieDate = class()

---@param s string
function CookieDate:new(s)
	self.s = s
	-- not implemented
end

---@return integer
function CookieDate:get_unix_time()
	return 0
end

---@return string
function CookieDate:__tostring()
	return self.s
end

return CookieDate
