local IHandler = require("web.IHandler")
local cookie_util = require("web.cookie.cookie_util")
local session_util = require("web.cookie.session_util")

---@class web.SessionContext: web.HandlerContext
---@field session table
local SessionContext = {}

---@class web.SessionHandler: web.IHandler
---@operator call: web.SessionHandler
local SessionHandler = IHandler + {}

---@param name string
---@param secret string
---@param handler web.IHandler
function SessionHandler:new(name, secret, handler)
	self.name = name
	self.secret = secret
	self.handler = handler
end

---@param req web.IRequest
---@param res web.IResponse
---@param ctx web.SessionContext
function SessionHandler:handle(req, res, ctx)
	local name, secret = self.name, self.secret

	local cookies = cookie_util.decode(req.headers["Cookie"])
	ctx.session = session_util.decode(cookies[name], secret) or {}

	self.handler:handle(req, res, ctx)

	---@type {[string]: string}
	cookies = {}
	cookies[name] = session_util.encode(ctx.session, secret)
	res.headers["Set-Cookie"] = cookie_util.encode(cookies)
end

return SessionHandler
