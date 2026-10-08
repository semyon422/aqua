local json = require("web.json")

-- Shared JSON column codec: Lua values are stored as JSON text and decoded on
-- read. Decode failures are database corruption and must fail loudly.
---@class ai.router.JsonCodec
local json_codec = {}

---@param value any
---@return string
function json_codec.encode(value)
	return json.encode(value)
end

---@param value string
---@return any
function json_codec.decode(value)
	local decoded, err = json.decode_safe(value)
	assert(decoded ~= nil, tostring(err))
	return decoded
end

return json_codec
