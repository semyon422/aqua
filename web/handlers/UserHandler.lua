local IHandler = require("web.IHandler")

---@class web.UserContext: web.HandlerContext
---@field session_user table
local UserContext = {}

---@class web.UserHandler: web.IHandler
---@operator call: web.UserHandler
local UserHandler = IHandler + {}

---@param handler web.IHandler
---@param domain table
function UserHandler:new(handler, domain)
	self.handler = handler
	self.domain = domain
end

---@param req web.IRequest
---@param res web.IResponse
---@param ctx web.SessionContext
function UserHandler:handle(req, res, ctx)
	---@cast ctx +web.UserContext
	ctx.session_user = self.domain:getUser(ctx.session.user_id)
	self.handler:handle(req, res, ctx)
end

return UserHandler
