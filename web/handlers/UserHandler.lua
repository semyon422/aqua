local IHandler = require("web.IHandler")

---@class web.UserContext: web.HandlerContext
---@field session table
---@field session_user table
local UserContext = {}

---@class web.UserHandler: web.IHandler
---@operator call: web.UserHandler
local UserHandler = IHandler + {}

---@param domain web.IDomain
function UserHandler:new(domain)
	self.domain = domain
end

---@param req web.IRequest
---@param res web.IResponse
---@param ctx web.UserContext
function UserHandler:handle(req, res, ctx)
	ctx.session_user = self.domain:getUser(ctx.session.user_id)
end

return UserHandler
