local class = require("class")

---@class web.RequestReader
---@operator call: web.RequestReader
---@field headers {[string]: string}
---@field method string
---@field uri string
---@field protocol string
---@field buffer string[]
local RequestReader = class()

function RequestReader:new()
	self.headers_read = false
	self.headers = {}
	self.buffer = {}
end

---@param char string
---@return string?
function RequestReader:readHeaderChar(char)

end

---@param s string
---@return string?
function RequestReader:readHeaders(s)
	for i = 1, #s do
		self:readHeaderChar(s:sub(i, i))
	end
end

---@param s string
---@return string?
function RequestReader:read(s)
	---@type string?
	local body_part = s

	if not self.headers_read then
		body_part = self:readHeaders(s)
	end

	return body_part
end

return RequestReader
