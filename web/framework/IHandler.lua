local class = require("class")

---@class web.HandlerContext
local HandlerContext = {}

---@class web.IHandler
---@operator call: web.IHandler
local IHandler = class()

---@param req web.IRequest
---@param res web.IResponse
---@param ctx web.HandlerContext
function IHandler:handle(req, res, ctx) end

return IHandler
