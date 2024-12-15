local IExtendedSocket = require("web.socket.IExtendedSocket")

---@class web.DecoratorSocket: web.IExtendedSocket
---@operator call: web.DecoratorSocket
local DecoratorSocket = IExtendedSocket + {}

---@param soc web.IExtendedSocket
function DecoratorSocket:new(soc)
	self.soc = soc
end

local methods = {
	"receive",
	"receiveany",
	"receiveuntil",
	"send",
	"close",
}

for _, name in ipairs(methods) do
	---@param self web.DecoratorSocket
	---@param ... any
	---@return any
	DecoratorSocket[name] = function(self, ...)  ---@diagnostic disable-line
		local soc = self.soc
		return soc[name](soc, ...)
	end
end

return DecoratorSocket
