local class = require("class")

---@class web.HandlerContext
local HandlerContext = {}

---@class web.IHandler
---@operator call: web.IHandler
local IHandler = class()

---@param handler web.IHandler?
function IHandler:new(handler)
	self.handler = handler
end

---@param req web.IRequest
---@param res web.IResponse
---@param ctx web.HandlerContext
function IHandler:handle(req, res, ctx)
	local handler = self.handler
	if handler then
		handler:handle(req, res, ctx)
	end
end

return IHandler
