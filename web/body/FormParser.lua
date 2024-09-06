local class = require("class")
local http_util = require("http_util")

---@class web.FormParser
---@operator call: web.FormParser
local FormParser = class()

---@param reader web.IBodyReader
function FormParser:new(reader)
	self.reader = reader
end

function FormParser:read()
	local body = self.reader:readAll()
	return http_util.decode_query_string(body)
end

return FormParser
