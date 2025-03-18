local class = require("class")

---@class web.Subprotocol
---@operator call: web.Subprotocol
local Subprotocol = class()

---@param ws web.Websocket
function Subprotocol:new(ws)
	self.ws = ws
end

---@param payload string
---@param fin boolean
function Subprotocol:continuation(payload, fin) end

---@param payload string
---@param fin boolean
function Subprotocol:text(payload, fin) end

function Subprotocol:binary(payload, fin) end

---@param code integer?
---@param payload string?
---@return integer?
---@return string?
function Subprotocol:close(code, payload)
	return code, payload
end

---@param payload string
---@return string?
function Subprotocol:ping(payload)
	return payload
end

---@param payload string
function Subprotocol:pong(payload) end

return Subprotocol
