local class = require("class")

---@class web.IBodyReader
---@operator call: web.IBodyReader
local IBodyReader = class()

---@return string?
function IBodyReader:read() end

---@return string
function IBodyReader:readAll()
	return ""
end

---@return fun(): string?
function IBodyReader:iter()
	return function() end
end

return IBodyReader
